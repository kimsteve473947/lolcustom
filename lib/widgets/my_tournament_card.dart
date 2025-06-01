import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lol_custom_game_manager/models/tournament_model.dart';

class MyTournamentCard extends StatelessWidget {
  final String id;
  final VoidCallback? onTap;
  
  const MyTournamentCard({
    Key? key, 
    required this.id,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('tournaments').doc(id).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context);
        }
        
        if (snapshot.hasError) {
          return _buildErrorCard(context, 'Error loading tournament');
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorCard(context, 'Tournament not found');
        }
        
        try {
          final data = snapshot.data!.data()!;
          data['id'] = snapshot.data!.id;
          final tournament = TournamentModel.fromMap(data);
          return _buildTournamentCard(context, tournament);
        } catch (e) {
          return _buildErrorCard(context, 'Error parsing tournament data');
        }
      },
    );
  }
  
  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
  
  Widget _buildErrorCard(BuildContext context, String message) {
    return Card(
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTournamentCard(BuildContext context, TournamentModel tournament) {
    final startTime = tournament.startTime.toDate();
    
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tournament.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${startTime.year}/${startTime.month}/${startTime.day} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '참가자: ${tournament.currentParticipants}/${tournament.maxParticipants}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 