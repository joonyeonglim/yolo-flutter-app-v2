import 'package:ultralytics_yolo/ultralytics_yolo.dart';

enum ModelType {
  detect,
  segment,
  classify,
  pose,
  obb;

  String get name {
    switch (this) {
      case ModelType.detect:
        return 'detect';
      case ModelType.segment:
        return 'segment';
      case ModelType.classify:
        return 'classify';
      case ModelType.pose:
        return 'pose';
      case ModelType.obb:
        return 'obb';
    }
  }

  String get modelName {
    switch (this) {
      case ModelType.detect:
        return 'yolo11n';
      case ModelType.segment:
        return 'yolo11n-seg';
      case ModelType.classify:
        return 'yolo11n-cls';
      case ModelType.pose:
        return 'yolo11n-pose';
      case ModelType.obb:
        return 'yolo11n-obb';
    }
  }

  YOLOTask get task {
    switch (this) {
      case ModelType.detect:
        return YOLOTask.detect;
      case ModelType.segment:
        return YOLOTask.segment;
      case ModelType.classify:
        return YOLOTask.classify;
      case ModelType.pose:
        return YOLOTask.pose;
      case ModelType.obb:
        return YOLOTask.obb;
    }
  }
}