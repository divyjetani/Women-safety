import 'package:flutter/material.dart';
import '../app/theme.dart';

class SafetyCard extends StatelessWidget {
  final int score;
  final String title;
  final String description;
  final int trend;

  const SafetyCard({
    super.key,
    required this.score,
    required this.title,
    required this.description,
    required this.trend,
  });

  Color getScoreColor() {
    if (score >= 80) return AppTheme.successColor;
    if (score >= 60) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            getScoreColor().withValues(alpha: 0.1),
            getScoreColor().withValues( alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: getScoreColor().withValues( alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: getScoreColor(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 18,
                        color: getScoreColor().withValues( alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      trend >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: trend >= 0 ? AppTheme.successColor : AppTheme.dangerColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trend >= 0 ? '+' : ''}$trend from last week',
                      style: TextStyle(
                        color: trend >= 0 ? AppTheme.successColor : AppTheme.dangerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: getScoreColor().withValues( alpha: 0.3),
                width: 8,
              ),
            ),
            child: Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: getScoreColor().withValues( alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    score >= 80 ? Icons.shield :
                    score >= 60 ? Icons.warning_amber : Icons.error,
                    color: getScoreColor(),
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}