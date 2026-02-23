import 'package:flutter/material.dart';
import 'package:characters/characters.dart';

/// Utility for generating user visuals, like initials for avatars.
class AvatarUtils {
  /// Returns the uppercase initials for a given [name].
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first.characters.first : '';
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }
}
