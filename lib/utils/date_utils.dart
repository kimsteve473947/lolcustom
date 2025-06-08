import 'package:intl/intl.dart';

// 날짜를 yyyy-MM-dd 형식으로 포맷
String formatDate(DateTime date) {
  final formatter = DateFormat('yyyy-MM-dd');
  return formatter.format(date);
}

// 시간을 HH:mm 형식으로 포맷
String formatTime(DateTime time) {
  final formatter = DateFormat('HH:mm');
  return formatter.format(time);
}

// 날짜와 시간을 yyyy-MM-dd HH:mm 형식으로 포맷
String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('yyyy-MM-dd HH:mm');
  return formatter.format(dateTime);
}

// 상대적 시간 표시 (방금, 5분 전, 1시간 전, 어제, 2023-01-01 등)
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inSeconds < 60) {
    return '방금';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}분 전';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}시간 전';
  } else if (difference.inDays < 2) {
    return '어제';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}일 전';
  } else {
    return formatDate(dateTime);
  }
}

// 주어진 날짜가 오늘인지 확인
bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

// 주어진 날짜가 어제인지 확인
bool isYesterday(DateTime date) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
} 