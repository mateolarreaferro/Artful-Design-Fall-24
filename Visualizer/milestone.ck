//-----------------------------------------------------------------------------
// name: sacredvis.ck
// desc: milestone MUS256/CS476
//-----------------------------------------------------------------------------

//************************** AUDIO SETTINGS **************************//
// Audio window and buffer sizes
2048 => int WINDOW_SIZE;
WINDOW_SIZE * 2 => int FFT_SIZE;

// Gain and input setup
Gain input;
1.0 => input.gain;

// Audio routing
adc => input => dac;
input => Flip accum => blackhole;  // Non-output signal path
input => PoleZero dcblock => FFT fft => blackhole;  // FFT for analysis

// DC blocker settings to remove low-frequency noise
0.99 => dcblock.blockZero;

// Windowing function to smooth the audio signal over the window size
Windowing.hann(WINDOW_SIZE) => fft.window;

// FFT and accumulation settings
FFT_SIZE => fft.size; 
WINDOW_SIZE => accum.size;

// Audio sample and frequency range settings
44100.0 => float SAMPLING_RATE;
80.0 => float MIN_FREQ;
12000.0 => float MAX_FREQ;

// Frequency range to FFT bin conversion
(MIN_FREQ / SAMPLING_RATE * FFT_SIZE) $ int => int min_bin;
(MAX_FREQ / SAMPLING_RATE * FFT_SIZE) $ int => int max_bin;

//************************** CHUGL SETTINGS **************************//
// Visualizer window setup
GWindow.title("Visualizer"); 
GCamera camera --> GG.scene(); 
camera.perspective();
GG.scene().camera().posZ(99); 

// Post-processing effects
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

// Bloom pass settings
2 => float intensity;
UI_Float bloom_intensity(bloom_pass.intensity());
UI_Float radius(bloom_pass.radius());
UI_Float threshold(bloom_pass.threshold());

// Tonemapping settings
[
"NONE", "LINEAR", "REINHARD", "CINEON", "ACES", "UNCHARTED",
] @=> string builtin_tonemap_algorithms[];
UI_Int tonemap(output_pass.tonemap());
UI_Int levels(bloom_pass.levels());
UI_Float exposure(output_pass.exposure());


// Renderers for waveform and spiral spectrogram
GLines waveform_display --> GG.scene(); 
waveform_display.width(0.5); 
waveform_display.color(@(1.0, 1.0, 1.0)); 

GLines spiral_spectrogram --> GG.scene();

//************************** VARIABLES **************************//
// Arrays for audio samples, FFT data, and visual positions
float samples[WINDOW_SIZE];
vec2 waveform_positions[WINDOW_SIZE];
complex fft_response[FFT_SIZE];
float magnitudes[max_bin - min_bin];
vec2 spiral_positions[max_bin - min_bin];
vec3 spiral_colors[max_bin - min_bin];

// Spiral and modulation settings
.001 => float previous_angle_increment;
.01 => float modulation_threshold;
.1 => float spiral_rotation_time;
2.0 => float base_spiral_radius;

// Spectrum color map (from blue to red)
6 => int numColors;
vec3 spectrumColorMap[numColors];
@(0.0, 0.0, 1.0) => spectrumColorMap[0];  // Blue
@(0.0, 1.0, 1.0) => spectrumColorMap[1];  // Cyan
@(0.0, 1.0, 0.0) => spectrumColorMap[2];  // Green
@(1.0, 1.0, 0.0) => spectrumColorMap[3];  // Yellow
@(1.0, 0.5, 0.0) => spectrumColorMap[4];  // Orange
@(1.0, 0.0, 0.0) => spectrumColorMap[5];  // Red

// Smoothing variables
0.1 => float angle_smoothing_factor;
0.1 => float magnitude_smoothing_factor;
0.1 => float spiral_radius_smoothing_factor;

// Arrays to store smoothed values
float smoothed_magnitudes[max_bin - min_bin];
float smoothed_radius[max_bin - min_bin];

//************************** FUNCTIONS **************************//

// Interpolate between two colors based on a ratio 't'
fun vec3 interpolateColor(vec3 c1, vec3 c2, float t) {
    return c1 + (c2 - c1) * t;
}

// Apply a smoothing factor to a value
fun float smoothValue(float previous_value, float new_value, float factor) {
    return previous_value + (new_value - previous_value) * factor;
}

// Get FFT data and calculate magnitude for each bin
fun void getFFTData() {
    fft.upchuck();
    fft.spectrum(fft_response);
    for (min_bin => int i; i < max_bin; i++) {
        20 * (fft_response[i] $ polar).mag => magnitudes[i - min_bin];
    }
}

// Calculate the overall magnitude (energy) of the spectrum
fun float calculateOverallMagnitude() {
    0.0 => float total_magnitude;
    for (0 => int i; i < magnitudes.size(); i++) {
        magnitudes[i] +=> total_magnitude;
    }
    return Math.sqrt(total_magnitude / magnitudes.size());
}

// Smooth FFT data
fun void smoothFFTData() {
    for (0 => int i; i < magnitudes.size(); i++) {
        smoothValue(smoothed_magnitudes[i], magnitudes[i], magnitude_smoothing_factor) => smoothed_magnitudes[i];
    }
}

// Map FFT magnitudes to spiral positions and colors
fun void map2spiralSpectrogram(vec2 out[], vec3 color_out[]) {
    calculateOverallMagnitude() => float overall_magnitude;
    
    // Adjust angle increment based on magnitude
    if (overall_magnitude > modulation_threshold) {
        smoothValue(previous_angle_increment, 10 + 0.1 * overall_magnitude, angle_smoothing_factor) => previous_angle_increment;
    }
    
    // Calculate radius and scale for spiral
    smoothValue(base_spiral_radius, 2 + 0.2 * Math.cos(now / second * 0.5 * Math.PI), spiral_radius_smoothing_factor) => base_spiral_radius;
    0.1 => float base_spiral_scale;
    
    // Update spiral rotation time
    spiral_rotation_time + GG.dt() * 0.2 => spiral_rotation_time;
    Math.PI * spiral_rotation_time => float spiral_rotation_angle;
    
    // Map FFT data to spiral positions
    for (0 => int i; i < magnitudes.size(); i++) {
        i * previous_angle_increment => float angle;
        smoothValue(5.0 + base_spiral_radius + base_spiral_scale * (i + 1) + magnitudes[i] * 0.05, smoothed_radius[i], spiral_radius_smoothing_factor) => smoothed_radius[i];
        
        // Set positions
        smoothed_radius[i] * Math.sin(angle + spiral_rotation_angle) => out[i].x;
        smoothed_radius[i] * Math.cos(angle + spiral_rotation_angle) => out[i].y;
        
        // Default color is white
        @(1.0, 1.0, 1.0) => color_out[i];
        
        // Color interpolation based on frequency
        if (magnitudes[i] > modulation_threshold) {
            (1.0 * i) / magnitudes.size() => float normalized_freq;
            normalized_freq * (spectrumColorMap.size() - 1) => float color_idx_f;
            Std.ftoi(color_idx_f) => int color_idx;
            color_idx_f % 1.0 => float color_lerp;
            
            // Prevent index out of bounds
            if (color_idx >= spectrumColorMap.size() - 1) {
                spectrumColorMap.size() - 2 => color_idx;
                1.0 => color_lerp;
            }
            
            // Interpolate between adjacent colors
            interpolateColor(spectrumColorMap[color_idx], spectrumColorMap[color_idx + 1], color_lerp) => color_out[i];
        }
    }
}

// Map audio samples to the waveform display
fun void mapWaveform(float in_samples[], vec2 out_positions[]) {
    .5 => float y_scale;
    0.1 => float x_spacing;
    (WINDOW_SIZE / 2.0) * x_spacing => float x_offset;
    
    // Set 2D positions for rendering
    for (0 => int i; i < WINDOW_SIZE; i++) {
        (i * x_spacing) - x_offset => out_positions[i].x;
        smoothValue(out_positions[i].y, in_samples[i] * y_scale, 0.5f) => out_positions[i].y;
    }
}

// Continuously process audio samples
fun void doAudio() {
    while (true) {
        accum.upchuck();
        accum.output(samples);
        smoothFFTData();
        WINDOW_SIZE::samp => now;
    }
}
spork ~ doAudio();

//************************** MAIN GRAPHICAL LOOP **************************//
while (true) {
    getFFTData();
    
    // Update waveform display
    mapWaveform(samples, waveform_positions);
    waveform_display.positions(waveform_positions);
    
    // Update spiral spectrogram display
    map2spiralSpectrogram(spiral_positions, spiral_colors);
    spiral_spectrogram.positions(spiral_positions);
    spiral_spectrogram.colors(spiral_colors);
    
    // Adjust spiral width based on magnitude
    0.2 * calculateOverallMagnitude() => spiral_spectrogram.width;
    
    GG.nextFrame() => now;
    
    // Display UI controls for the visualizer
    if (UI.begin("Visualizer")) {
        UI.scenegraph(GG.scene());
        if (UI.slider("Threshold", threshold, 0.0, 4.0)) {
            bloom_pass.threshold(threshold.val());
        }
        if (UI.slider("Intensity", bloom_intensity, 0.0, 1.0)) {
            bloom_pass.intensity(bloom_intensity.val());
        }
        if (UI.slider("Radius", radius, 0.0, 1.0)) {
            bloom_pass.radius(radius.val());
        }
        if (UI.slider("Levels", levels, 0, 10)) {
            bloom_pass.levels(levels.val());
        }
        UI.separator();
        if (UI.listBox("Tonemap Function", tonemap, builtin_tonemap_algorithms, -1)) {
            output_pass.tonemap(tonemap.val());
        }
        if (UI.slider("Exposure", exposure, 0, 4)) {
            output_pass.exposure(exposure.val());
        }
    }
    UI.end();
}
