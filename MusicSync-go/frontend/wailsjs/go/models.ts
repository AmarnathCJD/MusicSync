export namespace settings {
	
	export class AudioPreset {
	    id: string;
	    name: string;
	    blurb: string;
	
	    static createFrom(source: any = {}) {
	        return new AudioPreset(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.blurb = source["blurb"];
	    }
	}
	export class AudioSettings {
	    sample_rate: number;
	    frames: number;
	    beat_gain: number;
	    hue_drift: number;
	    brightness: number;
	    saturation: number;
	    smoothing: number;
	    beat_threshold: number;
	    silence_floor: number;
	    bass_falloff: number;
	    hue_spread: number;
	    gamma: number;
	    center_motion: number;
	    palette: string;
	    mono_hue: number;
	
	    static createFrom(source: any = {}) {
	        return new AudioSettings(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.sample_rate = source["sample_rate"];
	        this.frames = source["frames"];
	        this.beat_gain = source["beat_gain"];
	        this.hue_drift = source["hue_drift"];
	        this.brightness = source["brightness"];
	        this.saturation = source["saturation"];
	        this.smoothing = source["smoothing"];
	        this.beat_threshold = source["beat_threshold"];
	        this.silence_floor = source["silence_floor"];
	        this.bass_falloff = source["bass_falloff"];
	        this.hue_spread = source["hue_spread"];
	        this.gamma = source["gamma"];
	        this.center_motion = source["center_motion"];
	        this.palette = source["palette"];
	        this.mono_hue = source["mono_hue"];
	    }
	}
	export class VideoSettings {
	    monitor_index: number;
	    downscale_width: number;
	    capture_fps: number;
	    vertical_bias: number;
	    mirror: boolean;
	    saturation: number;
	    gamma: number;
	    highlight_gain: number;
	    highlight_at: number;
	    black_floor: number;
	    black_knee: number;
	    black_bar_cutoff: number;
	    temporal_dither: boolean;
	
	    static createFrom(source: any = {}) {
	        return new VideoSettings(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.monitor_index = source["monitor_index"];
	        this.downscale_width = source["downscale_width"];
	        this.capture_fps = source["capture_fps"];
	        this.vertical_bias = source["vertical_bias"];
	        this.mirror = source["mirror"];
	        this.saturation = source["saturation"];
	        this.gamma = source["gamma"];
	        this.highlight_gain = source["highlight_gain"];
	        this.highlight_at = source["highlight_at"];
	        this.black_floor = source["black_floor"];
	        this.black_knee = source["black_knee"];
	        this.black_bar_cutoff = source["black_bar_cutoff"];
	        this.temporal_dither = source["temporal_dither"];
	    }
	}
	export class Settings {
	    wled_ip: string;
	    port: number;
	    led_count: number;
	    skip_start: number;
	    skip_end: number;
	    send_fps: number;
	    follow_ms: number;
	    mode: string;
	    audio: AudioSettings;
	    video: VideoSettings;
	
	    static createFrom(source: any = {}) {
	        return new Settings(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.wled_ip = source["wled_ip"];
	        this.port = source["port"];
	        this.led_count = source["led_count"];
	        this.skip_start = source["skip_start"];
	        this.skip_end = source["skip_end"];
	        this.send_fps = source["send_fps"];
	        this.follow_ms = source["follow_ms"];
	        this.mode = source["mode"];
	        this.audio = this.convertValues(source["audio"], AudioSettings);
	        this.video = this.convertValues(source["video"], VideoSettings);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}

}

export namespace video {
	
	export class MonitorInfo {
	    index: number;
	    width: number;
	    height: number;
	    label: string;
	
	    static createFrom(source: any = {}) {
	        return new MonitorInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.index = source["index"];
	        this.width = source["width"];
	        this.height = source["height"];
	        this.label = source["label"];
	    }
	}

}

