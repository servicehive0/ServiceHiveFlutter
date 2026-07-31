// Converts a raw exception (SocketException, ClientException, TimeoutException,
// Supabase's PostgrestException, etc.) into a short message a non-technical
// user can act on, instead of leaking stack-trace-looking text like
// "ClientException with SocketException: Failed host lookup..." into the UI.
String friendlyError(Object error) {
  final raw = error.toString().toLowerCase();

  final looksOffline = raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection closed') ||
      raw.contains('clientexception');

  if (looksOffline) {
    return 'No internet connection. Please check your network and try again.';
  }

  if (raw.contains('timeoutexception') || raw.contains('timed out')) {
    return 'The request timed out. Please check your internet and try again.';
  }

  if (raw.contains('handshakeexception') || raw.contains('certificate')) {
    return 'Could not establish a secure connection. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}
