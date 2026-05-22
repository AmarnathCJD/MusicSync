import 'preset_anim.dart';

typedef AnimFactory = PresetAnim Function();

final Map<String, AnimFactory> _factories = {
  'pacifica':   () => PacificaAnim(),
  'aurora':     () => AuroraAnim(),
  'nebula':     () => NebulaAnim(),
  'galaxy':     () => GalaxyAnim(),
  'embers':     () => EmbersAnim(),
  'fire':       () => FireAnim(),
  'inferno':    () => InfernoAnim(),
  'candle':     () => CandleAnim(),
  'candelabra': () => CandelabraAnim(),
  'sunrise':    () => SunriseAnim(),
  'sunset':     () => SunsetAnim(),
  'moonlight':  () => MoonlightAnim(),
  'snowfall':   () => SnowfallAnim(),
  'frostbite':  () => FrostbiteAnim(),
  'lava':       () => LavaLampAnim(),
  'tropics':    () => TropicsAnim(),
  'rainforest': () => RainforestAnim(),
  'vapor':      () => VaporAnim(),
  'plasma':     () => PlasmaAnim(),
  'cyberpunk':  () => CyberpunkAnim(),
  'lightning':  () => LightningAnim(),
  'police':     () => PoliceAnim(),
  'heartbeat':  () => HeartbeatAnim(),
  'breathe':    () => BreatheAnim(),
  'rainbow':    () => RainbowAnim(),
  'candy':      () => CandyAnim(),
};

PresetAnim? animFor(String id) => _factories[id]?.call();
