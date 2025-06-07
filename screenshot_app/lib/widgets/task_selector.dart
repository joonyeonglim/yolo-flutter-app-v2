import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../services/inference_service.dart';

class TaskSelector extends StatelessWidget {
  const TaskSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InferenceService>(
      builder: (context, inference, child) {
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: YOLOTask.values.map((task) {
              final isSelected = inference.currentTask == task;
              return GestureDetector(
                onTap: () async {
                  await inference.switchTask(task);
                  // Trigger re-processing of current image if one exists
                  // This would be handled by the parent screen
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getTaskLabel(task),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getTaskLabel(YOLOTask task) {
    switch (task) {
      case YOLOTask.detect:
        return 'Detect';
      case YOLOTask.segment:
        return 'Segment';
      case YOLOTask.classify:
        return 'Classify';
      case YOLOTask.pose:
        return 'Pose';
      case YOLOTask.obb:
        return 'OBB';
    }
  }
}