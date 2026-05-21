import 'package:flutter/material.dart';

/// Curated WLED preset cards. fx/pal IDs come from WLED's built-in catalogue.
class EffectPreset {
  final String name;
  final String tagline;
  final IconData icon;
  final List<Color> swatch;
  final int fx;
  final int palette;
  final int speed;
  final int intensity;
  final List<int>? color;

  const EffectPreset({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.swatch,
    required this.fx,
    required this.palette,
    required this.speed,
    required this.intensity,
    this.color,
  });
}

const curatedPresets = <EffectPreset>[
  EffectPreset(
    name: 'Fire',
    tagline: 'crackling embers',
    icon: Icons.local_fire_department,
    swatch: [Color(0xFFFF3D00), Color(0xFFFFC107), Color(0xFFB71C1C)],
    fx: 66, // Fire 2012
    palette: 35, // Fire
    speed: 130,
    intensity: 200,
  ),
  EffectPreset(
    name: 'Snowfall',
    tagline: 'gentle drift',
    icon: Icons.ac_unit,
    swatch: [Color(0xFFFFFFFF), Color(0xFFB3E5FC), Color(0xFF1E88E5)],
    fx: 41, // Twinkle Fade
    palette: 21, // Cloud
    speed: 90,
    intensity: 130,
  ),
  EffectPreset(
    name: 'Aurora',
    tagline: 'northern lights',
    icon: Icons.waves,
    swatch: [Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFF00C853)],
    fx: 88, // Aurora
    palette: 50, // Aurora 2
    speed: 110,
    intensity: 160,
  ),
  EffectPreset(
    name: 'Ocean',
    tagline: 'rolling tide',
    icon: Icons.water,
    swatch: [Color(0xFF006064), Color(0xFF0097A7), Color(0xFFB2EBF2)],
    fx: 101, // Pacifica
    palette: 0,
    speed: 80,
    intensity: 128,
  ),
  EffectPreset(
    name: 'Lava Lamp',
    tagline: 'slow bubbles',
    icon: Icons.bubble_chart,
    swatch: [Color(0xFFFF6F00), Color(0xFFD500F9), Color(0xFFFFD600)],
    fx: 50, // Lava
    palette: 36, // Lava
    speed: 60,
    intensity: 180,
  ),
  EffectPreset(
    name: 'Forest',
    tagline: 'leafy ambient',
    icon: Icons.forest,
    swatch: [Color(0xFF2E7D32), Color(0xFF66BB6A), Color(0xFF1B5E20)],
    fx: 9, // Rainbow
    palette: 22, // Forest
    speed: 70,
    intensity: 140,
  ),
  EffectPreset(
    name: 'Sunset',
    tagline: 'warm fade',
    icon: Icons.wb_twilight,
    swatch: [Color(0xFFFF6F00), Color(0xFFD81B60), Color(0xFFFFC107)],
    fx: 2, // Breathe
    palette: 38, // Sunset
    speed: 60,
    intensity: 200,
  ),
  EffectPreset(
    name: 'Rainbow',
    tagline: 'classic cycle',
    icon: Icons.color_lens,
    swatch: [Color(0xFFE53935), Color(0xFFFFEB3B), Color(0xFF1E88E5)],
    fx: 9, // Rainbow
    palette: 11, // Rainbow
    speed: 140,
    intensity: 200,
  ),
  EffectPreset(
    name: 'Lightning',
    tagline: 'flickers + bolts',
    icon: Icons.bolt,
    swatch: [Color(0xFFFFFFFF), Color(0xFF7C4DFF), Color(0xFF263238)],
    fx: 56, // Lightning
    palette: 0,
    speed: 200,
    intensity: 220,
  ),
  EffectPreset(
    name: 'Plasma',
    tagline: 'liquid magenta',
    icon: Icons.blur_on,
    swatch: [Color(0xFFD500F9), Color(0xFF651FFF), Color(0xFF00E5FF)],
    fx: 49, // Plasma
    palette: 11,
    speed: 150,
    intensity: 180,
  ),
  EffectPreset(
    name: 'Candy',
    tagline: 'pastel sweep',
    icon: Icons.cake,
    swatch: [Color(0xFFF8BBD0), Color(0xFFB2EBF2), Color(0xFFFFF59D)],
    fx: 80, // Twinklefox
    palette: 14, // Pastel
    speed: 100,
    intensity: 140,
  ),
  EffectPreset(
    name: 'Galaxy',
    tagline: 'starry drift',
    icon: Icons.auto_awesome,
    swatch: [Color(0xFF311B92), Color(0xFFD500F9), Color(0xFF00E5FF)],
    fx: 75, // Colortwinkles
    palette: 26, // Magenta
    speed: 90,
    intensity: 200,
  ),
];
