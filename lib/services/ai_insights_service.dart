import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import '../core/config.dart';

/// AI/ML advisory features, two kinds:
///  1. LLM-based (rankAndScoreBids, assessCancellationRisk) — reason over
///     real Supabase data via the Groq chat-completions API already used
///     by AiServiceFinderScreen etc.
///  2. Trained-model-based (rankAndScoreBidsML) — calls our own scikit-learn
///     model (see Service-Hive-ML/train.py + app.py), a real classifier we
///     trained ourselves rather than an LLM call.
/// Every caller must treat a null result as "no insight available" and keep
/// the underlying screen fully functional without it.
class AiInsightsService {
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  // Our own trained model, served over HTTP by Service-Hive-ML/app.py,
  // deployed on Vercel. Override via --dart-define=ML_SERVICE_URL=... for
  // local dev against a local `uvicorn app:app` instance.
  static const _mlServiceUrl = String.fromEnvironment('ML_SERVICE_URL', defaultValue: kMlServiceUrl);

  static Future<dynamic> _callGroq(String systemPrompt, String userPrompt, {int maxTokens = 500}) async {
    final res = await http.post(
      Uri.parse(_url),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $kGroqApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': maxTokens,
        'temperature': 0.2,
      }),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) return null;
    final content = jsonDecode(res.body)['choices'][0]['message']['content'] as String;

    final objStart = content.indexOf('{');
    final arrStart = content.indexOf('[');
    if (arrStart != -1 && (objStart == -1 || arrStart < objStart)) {
      final arrEnd = content.lastIndexOf(']') + 1;
      if (arrEnd <= arrStart) return null;
      return jsonDecode(content.substring(arrStart, arrEnd));
    }
    if (objStart == -1) return null;
    final objEnd = content.lastIndexOf('}') + 1;
    if (objEnd <= objStart) return null;
    return jsonDecode(content.substring(objStart, objEnd));
  }

  /// Haversine distance in km between two lat/lng points.
  static double? distanceKm(double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Ranks bids on a request and scores each bid's likely job-success chance.
  /// Returns a map of bid_id -> {rank, success_score, reason}, or null on failure.
  static Future<Map<String, dynamic>?> rankAndScoreBids({
    required String serviceName,
    required String description,
    required String area,
    required String city,
    required List<Map<String, dynamic>> bids,
  }) async {
    if (bids.isEmpty) return null;
    try {
      final result = await _callGroq(
        'You are a service-marketplace ranking assistant. Given a customer job and a list of provider bids, rank the bids best-to-worst and give each a job-success likelihood percentage (0-100). Consider rating, experience, distance (closer is better), total completed jobs (more is better, signals reliability), price fairness, and how well the bid message addresses the job. Respond ONLY with a JSON array, one object per bid, no extra text: [{"bid_id":"...","rank":1,"success_score":87,"reason":"short reason"}]',
        'Job: "$serviceName" — $description\nLocation: $area, $city\n\nBids:\n${jsonEncode(bids)}',
        maxTokens: 700,
      );
      if (result is! List) return null;
      final byId = <String, dynamic>{};
      for (final r in result) {
        if (r is Map && r['bid_id'] != null) byId[r['bid_id'] as String] = r;
      }
      return byId;
    } catch (_) {
      return null;
    }
  }

  /// Same ranking task as rankAndScoreBids above, but scored by OUR OWN
  /// trained model (Service-Hive-ML/) instead of an LLM call — a real
  /// scikit-learn classifier trained on (rating, total_jobs, experience,
  /// distance, relative price) -> accepted/rejected. Returns the identical
  /// bid_id -> {success_score, rank} shape so callers can swap between the
  /// two with a one-line change.
  static Future<Map<String, dynamic>?> rankAndScoreBidsML({
    required List<Map<String, dynamic>> bids,
  }) async {
    if (bids.isEmpty) return null;
    try {
      final payload = bids.map((b) => {
        'bid_id': b['bid_id'],
        'price': b['price'],
        'rating': b['rating'],
        'total_jobs': b['total_jobs'],
        'experience': b['experience'],
        'distance_km': b['distance_km'],
      }).toList();

      final res = await http.post(
        Uri.parse('$_mlServiceUrl/rank-bids'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'bids': payload}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;
      final result = jsonDecode(res.body);
      if (result is! List) return null;
      final byId = <String, dynamic>{};
      for (final r in result) {
        if (r is Map && r['bid_id'] != null) byId[r['bid_id'] as String] = r;
      }
      return byId;
    } catch (_) {
      return null;
    }
  }

  /// Assesses cancellation risk for a provider's in-flight jobs.
  /// Returns a map of job_id -> {risk, reason}, or null on failure.
  static Future<Map<String, dynamic>?> assessCancellationRisk(List<Map<String, dynamic>> jobs) async {
    if (jobs.isEmpty) return null;
    try {
      final result = await _callGroq(
        'You are a booking risk assistant for a home-services marketplace. Given a list of active jobs (accepted or in-progress), estimate the cancellation risk for each as "low", "medium", or "high". A job accepted long ago with no OTP verification (work hasn\'t started) is riskier; a job with recent progress is safer. Respond ONLY with a JSON array: [{"job_id":"...","risk":"low|medium|high","reason":"short reason"}]',
        jsonEncode(jobs),
        maxTokens: 500,
      );
      if (result is! List) return null;
      final byId = <String, dynamic>{};
      for (final r in result) {
        if (r is Map && r['job_id'] != null) byId[r['job_id'] as String] = r;
      }
      return byId;
    } catch (_) {
      return null;
    }
  }

  /// Same task as assessCancellationRisk above, but classified by OUR OWN
  /// trained model (class-balanced Logistic Regression, see
  /// Service-Hive-ML/train_risk.py) instead of an LLM call. `jobs` items:
  /// {job_id, hours_since_accepted, otp_verified, provider_total_jobs,
  /// price, provider_avg_price}. Returns a map of job_id -> {risk}.
  static Future<Map<String, dynamic>?> assessCancellationRiskML(List<Map<String, dynamic>> jobs) async {
    if (jobs.isEmpty) return null;
    try {
      final res = await http.post(
        Uri.parse('$_mlServiceUrl/assess-risk'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'jobs': jobs}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;
      final result = jsonDecode(res.body);
      if (result is! Map) return null;
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return null;
    }
  }

  /// Classifies review texts as Positive/Neutral/Negative using OUR OWN
  /// trained NLP model (TF-IDF + Naive Bayes, see
  /// Service-Hive-ML/train_sentiment.py) — no LLM call. `reviews` items:
  /// {id, review}. Returns a map of id -> sentiment string.
  static Future<Map<String, dynamic>?> analyzeSentimentML(List<Map<String, dynamic>> reviews) async {
    if (reviews.isEmpty) return null;
    try {
      final res = await http.post(
        Uri.parse('$_mlServiceUrl/analyze-sentiment'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'reviews': reviews}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;
      final result = jsonDecode(res.body);
      if (result is! Map) return null;
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return null;
    }
  }

  /// Predicts an expected star rating (1.0-5.0) for providers without
  /// enough real reviews yet — OUR OWN trained regression model (see
  /// Service-Hive-ML/train_rating.py), not an LLM call. `providers` items:
  /// {provider_id, total_jobs, experience_years, avg_response_minutes,
  /// cancellations}. Returns a map of provider_id -> predicted_rating.
  static Future<Map<String, dynamic>?> predictProviderRatingML(List<Map<String, dynamic>> providers) async {
    if (providers.isEmpty) return null;
    try {
      final res = await http.post(
        Uri.parse('$_mlServiceUrl/predict-rating'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'providers': providers}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;
      final result = jsonDecode(res.body);
      if (result is! List) return null;
      final byId = <String, dynamic>{};
      for (final r in result) {
        if (r is Map && r['provider_id'] != null) byId[r['provider_id'] as String] = r['predicted_rating'];
      }
      return byId;
    } catch (_) {
      return null;
    }
  }

  /// Predicts a fair PKR price range for a job from its service type,
  /// city, and complexity — OUR OWN trained regression model (One-Hot
  /// Encoding + Random Forest, see Service-Hive-ML/train_price.py), not
  /// an LLM call. Returns {min_price, max_price} or null on failure.
  static Future<Map<String, dynamic>?> predictPriceML({
    required String serviceType,
    String? city,
    int complexity = 3,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_mlServiceUrl/predict-price'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'queries': [
            {
              'query_id': 'q1',
              'service_type': serviceType,
              'city': city,
              'complexity': complexity,
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;
      final result = jsonDecode(res.body);
      if (result is! List || result.isEmpty) return null;
      final first = result[0];
      if (first is! Map) return null;
      return {'min_price': first['min_price'], 'max_price': first['max_price']};
    } catch (_) {
      return null;
    }
  }
}
