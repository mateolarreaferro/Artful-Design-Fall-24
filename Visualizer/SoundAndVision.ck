//-----------------------------------------------------------------------------
// name: SacredVis.ck
// desc: Final Project Music 256 / CS 476
// by: Mateo Larrea
//-----------------------------------------------------------------------------

//************************** AUDIO SETTINGS **************************//
// Setup audio window, buffer, and routing
700 => int WINDOW_SIZE;
WINDOW_SIZE * 2 => int FFT_SIZE;

Gain input;
1.0 => input.gain;

adc => input => dac;
input => Flip accum => blackhole;
input => PoleZero dcblock => FFT fft => blackhole;

0.99 => dcblock.blockZero;
Windowing.hann(WINDOW_SIZE) => fft.window;
FFT_SIZE => fft.size;
WINDOW_SIZE => accum.size;

44100.0 => float SAMPLING_RATE;
20.0 => float MIN_FREQ;
10000.0 => float MAX_FREQ;

(MIN_FREQ / SAMPLING_RATE * FFT_SIZE) $ int => int min_bin;
(MAX_FREQ / SAMPLING_RATE * FFT_SIZE) $ int => int max_bin;

//************************** DELAY EFFECT **************************//
// Create Delay UGen
Delay delay => dac;          // Add delay before sending to DAC
0.5::second => delay.max;    // Set maximum delay time
0.25::second => delay.delay; // Set initial delay time (250 ms)
0.5 => delay.gain;           // Control the volume of the delayed signal (50% feedback)
input => delay;              // Route input through the delay

//************************** REVERB EFFECT **************************//
JCRev reverb => dac;         // Create a JCRev (reverb) UGen
0.1 => reverb.mix;           // Set the wet/dry mix (how much reverb is mixed in)
0.8 => reverb.gain;          // Adjust the reverb gain (how loud the reverb is)
delay => reverb;             // Route the delayed signal through the reverb


//************************** CHUGL SETTINGS **************************//
// Setup visualizer window, camera, and post-processing effects
GWindow.title("Visualizer");
GLines spiral_spectrogram --> GG.scene();
GCamera camera --> GG.scene();
camera.perspective();
GG.scene().camera().posZ(90);
GG.scene().camera().clip(1, 200);
GG.fullscreen();

GG.scene().camera().fov(45);
GG.scene().camera().clip(1, 200);

GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

2 => float intensity;
UI_Float bloom_intensity(bloom_pass.intensity());
UI_Float radius(bloom_pass.radius());
UI_Float threshold(bloom_pass.threshold());

output_pass.tonemap(4);
UI_Int tonemap(output_pass.tonemap());
UI_Int levels(bloom_pass.levels());
UI_Float exposure(output_pass.exposure());

GLines waveform_display --> GG.scene();
waveform_display.width(0.8);
waveform_display.color(@(1.0, 1.0, 1.0));

//************************** VARIABLES **************************//
// Setup arrays and variables for audio samples, FFT data, and visual positions
float samples[WINDOW_SIZE];
vec2 waveform_positions[WINDOW_SIZE];
complex fft_response[FFT_SIZE];
float magnitudes[max_bin - min_bin];
vec2 spiral_positions[max_bin - min_bin];
vec3 spiral_colors[max_bin - min_bin];

.001 => float previous_angle_increment;
0.001 => float modulation_threshold;
.001 => float spiral_rotation_time;
2.0 => float base_spiral_radius;

6 => int numColors;
vec3 spectrumColorMap[numColors];
@(0.0, 0.0, 1.0) => spectrumColorMap[0];
@(0.0, 1.0, 1.0) => spectrumColorMap[1];
@(0.0, 1.0, 0.0) => spectrumColorMap[2];
@(1.0, 1.0, 0.0) => spectrumColorMap[3];
@(1.0, 0.5, 0.0) => spectrumColorMap[4];
@(1.0, 0.0, 0.0) => spectrumColorMap[5];

0.01 => float angle_smoothing_factor;
0.1 => float magnitude_smoothing_factor;
0.5 => float spiral_radius_smoothing_factor;

float smoothed_magnitudes[max_bin - min_bin];
float smoothed_radius[max_bin - min_bin];

UI_Float3 particle_start_color(Color.SKYBLUE);
UI_Float3 particle_end_color(Color.RED);
0.75 => float particle_lifetime;
0.15 => float amplitude_threshold;

//************************** PARTICLE SYSTEM **************************//
// Particle class definition and system instantiation
CircleGeometry particle_geo;
300 => int PARTICLE_POOL_SIZE;
Particle particles[PARTICLE_POOL_SIZE];

class Particle {
    FlatMaterial particle_mat;
    GMesh particle_mesh(particle_geo, particle_mat) --> GG.scene();
    0 => particle_mesh.sca;

    float angle;
    float radius;
    float angular_velocity;
    time spawn_time;
    vec3 color;
}

class ParticleSystem {
    int num_active;

    fun void update(float dt) {
        for (0 => int i; i < num_active; i++) {
            particles[i] @=> Particle p;

            if (now - p.spawn_time >= particle_lifetime::second) {
                0 => p.particle_mesh.sca;
                num_active--;
                particles[num_active] @=> particles[i];
                p @=> particles[num_active];
                i--;
                continue;
            }

            (now - p.spawn_time) / particle_lifetime::second => float t;
            p.color + (particle_end_color.val() - p.color) * t => p.particle_mat.color;
            p.particle_mesh.sca(1 - t);
            p.angle + (4 * Math.PI * dt / particle_lifetime) => p.angle;

            p.radius * Math.cos(p.angle) => float x;
            p.radius * Math.sin(p.angle) => float y;

            vec3 particle_position;
            x => particle_position.x;
            y => particle_position.y;
            0 => particle_position.z;
            p.particle_mesh.pos(particle_position);
        }
    }

    fun void spawnParticle(vec3 pos, vec3 color, float radius) {
        if (num_active < PARTICLE_POOL_SIZE) {
            particles[num_active] @=> Particle p;

            0 => p.angle;
            radius => p.radius;
            (Math.PI / particle_lifetime) => p.angular_velocity;

            color => p.color;
            color => p.particle_mat.color;

            now => p.spawn_time;
            pos => p.particle_mesh.pos;
            num_active++;
        }
    }
}

ParticleSystem ps;

//************************** FRAME SETUP **************************//
// Setup frames around the screen using planes attached to the camera
30 => float frame_thickness;
150 => float frame_size;

GPlane westPlane --> camera;
-75.0 => westPlane.posX;
frame_thickness => westPlane.scaX;
frame_size => westPlane.scaY;
0.1 => westPlane.scaZ;
@(1.0, 1.0, 1.0) => westPlane.color;

GPlane eastPlane --> camera;
75.0 => eastPlane.posX;
frame_thickness => eastPlane.scaX;
frame_size => eastPlane.scaY;
0.1 => eastPlane.scaZ;
@(1.0, 1.0, 1.0) => eastPlane.color;

GPlane northPlane --> camera;
50.0 => northPlane.posY;
frame_size => northPlane.scaX;
frame_thickness => northPlane.scaY;
0.1 => northPlane.scaZ;
@(1.0, 1.0, 1.0) => northPlane.color;

GPlane southPlane --> camera;
-50.0 => southPlane.posY;
frame_size => southPlane.scaX;
frame_thickness => southPlane.scaY;
0.1 => southPlane.scaZ;
@(1.0, 1.0, 1.0) => southPlane.color;

//************************** FUNCTIONS **************************//
// Interpolate between two colors
fun vec3 interpolateColor(vec3 c1, vec3 c2, float t) {
    return c1 + (c2 - c1) * t;
}

// Apply a smoothing factor to a value
fun float smoothValue(float previous_value, float new_value, float factor) {
    return previous_value + (new_value - previous_value) * factor;
}

// Get FFT data and calculate magnitudes
fun void getFFTData() {
    fft.upchuck();
    fft.spectrum(fft_response);
    for (min_bin => int i; i < max_bin; i++) {
        15 * (fft_response[i] $ polar).mag => magnitudes[i - min_bin];
    }
}

// Smooth FFT data
fun void smoothFFTData() {
    for (0 => int i; i < magnitudes.size(); i++) {
        smoothValue(smoothed_magnitudes[i], magnitudes[i], magnitude_smoothing_factor) => smoothed_magnitudes[i];
    }
}

// Calculate overall magnitude of the spectrum
fun float calculateOverallMagnitude() {
    0.0 => float total_magnitude;
    for (0 => int i; i < magnitudes.size(); i++) {
        magnitudes[i] +=> total_magnitude;
    }
    return Math.sqrt(total_magnitude / magnitudes.size());
}

// Find the highest frequency bin
fun int getHighestFrequencyBin() {
    0 => int max_bin_index;
    for (min_bin => int i; i < max_bin; i++) {
        if (magnitudes[i - min_bin] > magnitudes[max_bin_index]) {
            i - min_bin => max_bin_index;
        }
    }
    return max_bin_index;
}

// Map FFT magnitudes to spiral spectrogram positions and colors
fun void map2spiralSpectrogram(vec2 out[], vec3 color_out[]) {
    calculateOverallMagnitude() => float overall_magnitude;

    if (overall_magnitude > modulation_threshold) {
        smoothValue(previous_angle_increment, 10 + 0.1 * overall_magnitude, angle_smoothing_factor) => previous_angle_increment;
    }

    smoothValue(base_spiral_radius, 2 + 0.2 * Math.cos(now / second * 0.5 * Math.PI), spiral_radius_smoothing_factor) => base_spiral_radius;

    (0.3 * Math.cos((now / second) * (Math.TWO_PI / 30.0)) + 0.4) => float base_spiral_scale;

    spiral_rotation_time + GG.dt() * 0.2 => spiral_rotation_time;
    Math.PI * spiral_rotation_time => float spiral_rotation_angle;

    for (0 => int i; i < magnitudes.size(); i++) {
        i * previous_angle_increment => float angle;
        smoothValue(5.0 + base_spiral_radius + base_spiral_scale * (i + 1) + magnitudes[i] * 0.05, smoothed_radius[i], spiral_radius_smoothing_factor) => smoothed_radius[i];

        smoothed_radius[i] * Math.sin(angle + spiral_rotation_angle) => out[i].x;
        smoothed_radius[i] * Math.cos(angle + spiral_rotation_angle) => out[i].y;

        @(1.0, 1.0, 1.0) => color_out[i];

        if (magnitudes[i] > modulation_threshold) {
            (1.0 * i) / magnitudes.size() => float normalized_freq;
            normalized_freq * (spectrumColorMap.size() - 1) => float color_idx_f;
            Std.ftoi(color_idx_f) => int color_idx;
            color_idx_f % 1.0 => float color_lerp;

            if (color_idx >= spectrumColorMap.size() - 1) {
                spectrumColorMap.size() - 2 => color_idx;
                1.0 => color_lerp;
            }

            interpolateColor(spectrumColorMap[color_idx], spectrumColorMap[color_idx + 1], color_lerp) => color_out[i];
        }
    }
}

// Map audio samples to waveform positions
fun void mapWaveform(float in_samples[], vec2 out_positions[]) {
    .5 => float y_scale;
    0.193 => float x_spacing;
    (WINDOW_SIZE / 2.0) * x_spacing => float x_offset;

    for (0 => int i; i < WINDOW_SIZE; i++) {
        (i * x_spacing) - x_offset => out_positions[i].x;
        smoothValue(out_positions[i].y, in_samples[i] * y_scale, 0.5f) => out_positions[i].y;
    }
}

// Process audio continuously
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
// Update the visual elements in the main loop
while (true) {
    getFFTData();

    mapWaveform(samples, waveform_positions);
    waveform_display.positions(waveform_positions);

    map2spiralSpectrogram(spiral_positions, spiral_colors);
    spiral_spectrogram.positions(spiral_positions);
    spiral_spectrogram.colors(spiral_colors);

    (0.03 * Math.cos((now / second) * (Math.TWO_PI / 40)) + 0.04) => float modulated_width;
    modulated_width * calculateOverallMagnitude() => spiral_spectrogram.width;

    getHighestFrequencyBin() => int highest_bin;
    spectrumColorMap[highest_bin % numColors] => vec3 particle_color;

    if (highest_bin >= 0 && highest_bin < smoothed_radius.size()) {
        vec3 particle_pos;
        smoothed_radius[highest_bin] * Math.cos(previous_angle_increment * highest_bin) => particle_pos.x;
        smoothed_radius[highest_bin] * Math.sin(previous_angle_increment * highest_bin) => particle_pos.y;
        0 => particle_pos.z;

        if (calculateOverallMagnitude() > amplitude_threshold) {
            ps.spawnParticle(particle_pos, particle_color, smoothed_radius[highest_bin]);
        }
    }

    GG.nextFrame() => now;
    ps.update(GG.dt());

    if (UI.begin("Visualizer")) {
        UI.scenegraph(GG.scene());
    }
    UI.end();
} 
