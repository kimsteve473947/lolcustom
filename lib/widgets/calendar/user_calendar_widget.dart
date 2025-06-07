import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/services/tournament_service.dart';

class UserCalendarWidget extends StatefulWidget {
  final Function(DateTime) onDateSelected;

  const UserCalendarWidget({
    Key? key,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<UserCalendarWidget> createState() => _UserCalendarWidgetState();
}

class _UserCalendarWidgetState extends State<UserCalendarWidget> {
  late DateTime _selectedMonth;
  late TournamentService _tournamentService;
  List<DateTime> _tournamentDates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _tournamentService = TournamentService();
    _loadTournamentDates();
  }

  Future<void> _loadTournamentDates() async {
    setState(() {
      _isLoading = true;
    });

    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final dates = await _tournamentService.getUserTournamentDates(
      startDate: startDate,
      endDate: endDate,
    );

    setState(() {
      _tournamentDates = dates;
      _isLoading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _loadTournamentDates();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
    _loadTournamentDates();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasTournament(DateTime date) {
    return _tournamentDates.any((tournamentDate) =>
        tournamentDate.year == date.year &&
        tournamentDate.month == date.month &&
        tournamentDate.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 월 선택 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  '${_selectedMonth.year}년 ${_selectedMonth.month}월',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 요일 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weekdayHeader('일', Colors.red),
                _weekdayHeader('월'),
                _weekdayHeader('화'),
                _weekdayHeader('수'),
                _weekdayHeader('목'),
                _weekdayHeader('금'),
                _weekdayHeader('토', Colors.blue),
              ],
            ),
            const SizedBox(height: 8),
            
            // 캘린더 그리드
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarGrid(),
                
            // 설명
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.circle, color: AppColors.primary, size: 12),
                SizedBox(width: 4),
                Text('내전 일정', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayHeader(String text, [Color? color]) {
    return SizedBox(
      width: 30,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // 현재 월의 일 수 계산
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    // 이번 달 1일의 요일 구하기 (0: 일요일, 6: 토요일)
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 일요일을 0으로 변환
    
    // 이전 달의 마지막 날짜 구하기
    final lastDayOfPrevMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 0).day;
    
    // 다음 달의 첫 번째 날짜
    final nextMonthDays = (firstWeekday + daysInMonth) % 7 == 0 
        ? 0 
        : 7 - ((firstWeekday + daysInMonth) % 7);
    
    final totalDays = firstWeekday + daysInMonth + nextMonthDays;
    final totalWeeks = (totalDays / 7).ceil();
    
    List<Widget> weeks = [];
    
    for (int week = 0; week < totalWeeks; week++) {
      List<Widget> days = [];
      
      for (int i = 0; i < 7; i++) {
        final index = week * 7 + i;
        final dayNumber = index - firstWeekday + 1;
        
        if (dayNumber < 1) {
          // 이전 달 날짜
          final prevMonthDay = lastDayOfPrevMonth - (firstWeekday - index - 1);
          days.add(_buildDayCell(prevMonthDay, true, false));
        } else if (dayNumber > daysInMonth) {
          // 다음 달 날짜
          final nextMonthDay = dayNumber - daysInMonth;
          days.add(_buildDayCell(nextMonthDay, true, false));
        } else {
          // 현재 달 날짜
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
          final isToday = _isToday(date);
          final hasTournament = _hasTournament(date);
          
          days.add(
            GestureDetector(
              onTap: () => widget.onDateSelected(date),
              child: _buildDayCell(
                dayNumber,
                false,
                isToday,
                hasTournament,
                i == 0 ? Colors.red : (i == 6 ? Colors.blue : null),
              ),
            ),
          );
        }
      }
      
      weeks.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days,
        ),
      );
    }
    
    return Column(
      children: weeks.map((week) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: week,
      )).toList(),
    );
  }

  Widget _buildDayCell(int day, bool isOtherMonth, bool isToday, [bool hasTournament = false, Color? textColor]) {
    final color = isOtherMonth ? Colors.grey.shade300 : Colors.transparent;
    final textStyle = TextStyle(
      color: isOtherMonth ? Colors.grey.shade400 : textColor,
      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
    );
    
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            day.toString(),
            style: textStyle,
          ),
          if (hasTournament)
            Positioned(
              bottom: 2,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 