String formatDuration(int? seconds) {
  if (seconds == null) return "0s";
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);

  String formatted = '';
  if (hours > 0) formatted += '${hours}h ';
  if (minutes > 0 || hours > 0) formatted += '${minutes}m ';
  formatted += '${secs}s';
  return formatted;
}