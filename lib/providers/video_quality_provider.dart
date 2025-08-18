import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_compress/video_compress.dart';

enum VideoQualityLevel {
  low,
  medium,
  high,
  original,
}

final videoQualityProvider = StateProvider<VideoQualityLevel>((ref) => VideoQualityLevel.medium);

class VideoQualitySettings {
  static VideoQuality getVideoCompressQuality(VideoQualityLevel level) {
    switch (level) {
      case VideoQualityLevel.low:
        return VideoQuality.LowQuality;
      case VideoQualityLevel.medium:
        return VideoQuality.MediumQuality;
      case VideoQualityLevel.high:
        return VideoQuality.HighestQuality;
      case VideoQualityLevel.original:
        return VideoQuality.DefaultQuality;
    }
  }
  
  static String getQualityLabel(VideoQualityLevel level) {
    switch (level) {
      case VideoQualityLevel.low:
        return 'Low - Smaller file size';
      case VideoQualityLevel.medium:
        return 'Medium - Balanced quality';
      case VideoQualityLevel.high:
        return 'High - Better quality';
      case VideoQualityLevel.original:
        return 'Original - No compression';
    }
  }
  
  static String getQualityDescription(VideoQualityLevel level) {
    switch (level) {
      case VideoQualityLevel.low:
        return 'Optimized for slower connections and storage';
      case VideoQualityLevel.medium:
        return 'Good balance of quality and file size';
      case VideoQualityLevel.high:
        return 'Higher quality for better viewing experience';
      case VideoQualityLevel.original:
        return 'No compression - largest file size';
    }
  }
}