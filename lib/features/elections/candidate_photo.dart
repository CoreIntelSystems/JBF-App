import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/ui.dart';

/// A candidate's picture (kept in the cloud as a small image), or their
/// initials when there is none.
class CandidatePhoto extends StatelessWidget {
  const CandidatePhoto({
    super.key,
    required this.name,
    this.photo,
    this.size = 64,
  });

  final String name;
  final String? photo;
  final double size;

  static Uint8List? decode(String? dataUrl) {
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decode(photo);
    if (bytes == null) return InitialsAvatar(name, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => InitialsAvatar(name, size: size),
      ),
    );
  }
}
