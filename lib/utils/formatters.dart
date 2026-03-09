String formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(1)} ${units[i]}';
}

String formatSpeed(int bytesPerSec) {
  if (bytesPerSec <= 0) return '0 B/s';
  return '${formatSize(bytesPerSec)}/s';
}

String formatEta(int seconds) {
  if (seconds < 0) return '--';
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m}m';
}

String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  } catch (_) {
    return dateStr;
  }
}
