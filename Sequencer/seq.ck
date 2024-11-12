// Set up the camera and background color
GG.camera().orthographic();
@(1, 1, 1) => GG.scene().backgroundColor;

0 => float bg_time; // Initialize background time
(2.0 * Math.PI) / 60.0 => float bg_omega; // Angular frequency for a 60-second cycle

GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.3 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

UI_Float3 start_color(@(1.0, 0.063, 0.122));
UI_Float3 end_color(@(1.0, 0.063, 0.122));
UI_Float lifetime(2.0);
UI_Float3 background_color(GG.scene().backgroundColor());
CircleGeometry particle_geo;
particle_geo.build(1.0, 64, 0.0, 2.0 * Math.PI); // Using 64 segments for smoother particles

0.2::second => dur cooldown_duration;
now => time last_spawn_time;

// Adjusted sizes to be 20% smaller
3 * 0.8 => float base_circle_size;
base_circle_size => float current_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.1 => float sin_speed;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

// Adjusted positions for rendering order
-0.01 => float frame_circle_z;
0.0 => float env_circle_z;
0.01 => float nd_circle_z;

1.02 * base_circle_size => float frame_circle_size;
CircleGeometry frame_circle_geo;
FlatMaterial frame_circle_material;
GMesh frame_circle_mesh(frame_circle_geo, frame_circle_material) --> GG.scene();

// Set frame circle position with adjusted z
@(0.0, 0.0, frame_circle_z) => frame_circle_mesh.pos;

frame_circle_geo.build(frame_circle_size, 64, 0.0, 2.0 * Math.PI); // Increased segments to 64
@(0.0, 0.0, 0.0) => frame_circle_material.color;

CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Set environment circle position with adjusted z
@(circle_center.x, circle_center.y, env_circle_z) => center_circle_mesh.pos;

center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI); // Increased segments to 64
@(0.8, 0.8, 0.8) => center_circle_material.color;

// Variables for the natural disaster circle
float ndCircle_size;
vec3 ndCircle_position;
CircleGeometry ndCircle_geo;
FlatMaterial ndCircle_material;
GMesh ndCircle_mesh;
time ndCircle_start_time;
0 => int ndCircle_active; // ndCircle is initially not active
0.0 => float ndCircle_scale; // Current scale of the ndCircle

now => time last_ndCircle_time;
Math.random2f(15.0, 40.0)::second => dur ndCircle_interval; // Interval between appearances
5.0 => float ndCircle_lifespan; // ndCircle lifespan is 5 seconds
5.0 => float ndCircle_shrink_duration; // Shrink duration is 5 seconds

// Define colors
@(1.0, 0.063, 0.122) => vec3 blue_color; // Changed blue_color to specified color
@(0.965, 0.682, 0.176) => vec3 yellow_color;
// Changed purple_color to cyan
@(0.0, 1.0, 1.0) => vec3 purple_color;
@(1.0, 0.5, 0.0) => vec3 orange_color; // Added orange color
@(1.0, 0.0, 1.0) => vec3 pink_color;
@(0.0, 1.0, 0.0) => vec3 green_color;

// Particle speed and lifetime constants
0.6 => float slowSpeed;
1.0 => float midSpeed;
1.5 => float fastSpeed;

2.0 => float normalLifetime; // For normal-based
1.0 => float smallLifetime;  // For small-based
0.5 => float tinyLifetime;   // For tiny-based

// Maximum number of simultaneous voices
10 => int MAX_VOICES;

// List to keep track of active SndBufs
SndBuf activeVoices[0];

// Function to play a looping sound for a sphere
fun void playLoopingSound(Sphere @ s) {
    if (activeVoices.size() < MAX_VOICES) {
        new SndBuf @=> s.sound;
        s.sound => dac;
        // Choose sound file based on size category
        "" => string filename;
        if (s.sizeCategory == 0) {
            // Randomly select a file from "samples/normal/normal_1.wav" to "samples/normal/normal_8.wav"
            Math.random2(1, 40) => int randIndex; // Random integer between 1 and 8 inclusive
            "samples/normal/" + randIndex + ".wav" => filename;
        } else if (s.sizeCategory == 1) {
            "samples/sl.wav" => filename;
        } else if (s.sizeCategory == 2) {
            "samples/tl.wav" => filename;
        } else {
            "samples/nl.wav" => filename; // default
        }
        s.sound.read(filename);
        s.sound.loop(1);
        s.sound.rate(1.0);
        s.sound.gain(1.0 / (activeVoices.size() + 1)); // Adjust gain
        s.sound.play();

        // Add to active voices
        activeVoices << s.sound;

        // Adjust gain for all active voices
        0 => int i;
        for (; i < activeVoices.size(); i++) {
            activeVoices[i].gain(1.0 / activeVoices.size());
        }
    }
}

// Function to stop a sound associated with a sphere
fun void stopLoopingSound(Sphere @ s) {
    if (s.sound != null) {
        s.sound.rate(0);
        s.sound =< dac;
        // Remove from active voices
        0 => int i;
        for (; i < activeVoices.size(); i++) {
            if (activeVoices[i] == s.sound) {
                activeVoices.erase(i);
                break;
            }
        }
        // Adjust gain for remaining active voices
        if (activeVoices.size() > 0) {
            0 => int j;
            for (; j < activeVoices.size(); j++) {
                activeVoices[j].gain(1.0 / activeVoices.size());
            }
        }
        null @=> s.sound;
    }
}

class Particle {
    FlatMaterial particle_mat;
    GMesh particle_mesh(particle_geo, particle_mat) --> GG.scene();
    0.1 => particle_mesh.sca;

    vec2 direction;
    time spawn_time;
    vec3 color;
    float speed;
    float life_multiplier;
}

256 => int PARTICLE_POOL_SIZE; // Increased pool size
Particle particles[PARTICLE_POOL_SIZE];

fun float easeInOutCubic(float t) {
    return (t < 0.5) ? (4.0 * t * t * t) : (1.0 - Math.pow(-2.0 * t + 2.0, 3.0) / 2.0);
}

10 => float speedFactor;

class Sphere {
    SphereGeometry @ sphere_geo;
    FlatMaterial @ sphere_mat;
    GMesh @ sphere_mesh;
    vec3 position;
    vec3 target_position;
    float scale;
    int shrinking;
    int isBlue;
    int sizeCategory; // 0: normal, 1: small, 2: tiny
    int soundPlayed;  // Flag to track if dying sound has been played
    SndBuf @ sound;   // Reference to the associated SndBuf
    time spawn_time;  // Time when sphere was instantiated

    // Modified init function to accept color and size category
    fun void init(vec3 pos, int color, float size, int category) {
        new SphereGeometry @=> sphere_geo;
        // Corrected build call with all required arguments
        sphere_geo.build(1.0, 64, 64, 0.0, 2.0 * Math.PI, 0.0, Math.PI);
        new FlatMaterial @=> sphere_mat;
        sphere_mat.color((color == 1) ? blue_color : yellow_color);
        new GMesh(sphere_geo, sphere_mat) @=> sphere_mesh;
        sphere_mesh --> GG.scene();
        size => scale;
        0.0 => sphere_mesh.sca; // Start with zero scale
        pos => position;
        pos => sphere_mesh.pos;
        pos => target_position;
        0 => shrinking;
        category => sizeCategory;
        0 => soundPlayed; // Initialize soundPlayed to 0
        null @=> sound;    // Initialize sound to null
        now => spawn_time; // Record spawn time

        if (color == 1) {
            1 => isBlue;
        } else {
            0 => isBlue;
        }
    }
}

Sphere @ spheres[0];

class ParticleSystem {
    0 => int num_active;
    float circle_size;

    // Cooldown variables for sphere instantiation
    time last_sphere_instantiation_time;
    dur sphere_cooldown_duration;

    // Initializes the particle system with the current circle size
    fun void init(float currentSize) {
        currentSize => circle_size;
        now - 3::second => last_sphere_instantiation_time; // Initialize to allow immediate instantiation
        3::second => sphere_cooldown_duration; // Cooldown duration of 3 seconds
    }

    // Updates active particles
    fun void update(float dt) {
        for (0 => int i; i < num_active; i++) {
            particles[i] @=> Particle p;

            lifetime.val() * p.life_multiplier => float particle_lifetime;

            if (now - p.spawn_time >= particle_lifetime::second) {
                0 => p.particle_mesh.sca;
                num_active--;
                particles[num_active] @=> particles[i];
                p @=> particles[num_active];
                i--;
                continue;
            }

            {
                // Adjusted scale to make particles 75% smaller
                0.075 * (1.0 - Math.pow(((now - p.spawn_time) / second) / particle_lifetime, 0.2)) => p.particle_mesh.sca;
                p.color + (end_color.val() - p.color) * Math.pow(((now - p.spawn_time) / second) / particle_lifetime, 0.5) => p.particle_mat.color;
                (dt * p.direction).x * p.speed => p.particle_mesh.translateX;
                (dt * p.direction).y * p.speed => p.particle_mesh.translateY;
            }
        }
    }

    // Spawns a new particle at a given position with specified properties
    fun void spawnParticle(vec3 pos, vec3 color, float speedMultiplier, float lifeMultiplier) {
        if (num_active < PARTICLE_POOL_SIZE) {
            particles[num_active] @=> Particle p;

            // Randomize color slightly
            vec3 random_variation;
            Math.random2f(-0.05, 0.05) => random_variation.x;
            Math.random2f(-0.05, 0.05) => random_variation.y;
            Math.random2f(-0.05, 0.05) => random_variation.z;
            color + random_variation => p.color;
            p.color => p.particle_mat.color;

            Math.random2f(0.0, 2.0 * Math.PI) => float random_angle;
            Math.cos(random_angle) => p.direction.x;
            Math.sin(random_angle) => p.direction.y;

            now => p.spawn_time;
            pos => p.particle_mesh.pos;
            speedMultiplier => p.speed;
            lifeMultiplier => p.life_multiplier;
            num_active++;
        }
    }

    // Updates spheres, including movement and collision detection
    fun void updateSpheres(float dt) {
        for (0 => int i; i < spheres.size(); i++) {
            spheres[i] @=> Sphere @ s1;

            for (i + 1 => int j; j < spheres.size(); j++) {
                spheres[j] @=> Sphere @ s2;

                Math.sqrt(Math.pow(s1.position.x - s2.position.x, 2.0) + Math.pow(s1.position.y - s2.position.y, 2.0)) => float distance;

                if (distance <= (s1.scale + s2.scale) * 0.8) {
                    vec3 collision_pos;
                    (s1.position + s2.position) / 2.0 => collision_pos;

                    // Determine collision type
                    int collisionType;
                    if (s1.sizeCategory == s2.sizeCategory) {
                        s1.sizeCategory => collisionType; // 0: normal-normal, 1: small-small, 2: tiny-tiny
                    } else {
                        3 => collisionType; // Mixed sizes
                    }

                    vec3 collision_color;

                    // Determine particle color according to the color rules
                    if (s1.isBlue != s2.isBlue) {
                        // Spheres have different colors
                        // Yellow is dominant
                        if (s1.isBlue == 0 || s2.isBlue == 0) {
                            // At least one sphere is Yellow
                            yellow_color => collision_color;
                        } else {
                            // Both are Blue (should not reach here)
                            blue_color => collision_color;
                        }
                    } else {
                        // Spheres have same color
                        if (s1.isBlue == 0) {
                            // Both are Yellow
                            orange_color => collision_color;
                        } else {
                            // Both are Blue
                            purple_color => collision_color;
                        }
                    }

                    // Determine particle speed and lifetime according to size categories
                    float particleSpeed;
                    float particleLife;

                    // Determine size-based lifetime
                    if (s1.sizeCategory == 0 || s2.sizeCategory == 0) {
                        // At least one normal sphere
                        normalLifetime => particleLife;
                    } else if (s1.sizeCategory == 1 || s2.sizeCategory == 1) {
                        // At least one small sphere
                        smallLifetime => particleLife;
                    } else {
                        // Both tiny spheres
                        tinyLifetime => particleLife;
                    }

                    // Determine speed according to collision sizes
                    if (s1.sizeCategory == 2 && s2.sizeCategory == 2) {
                        // tiny + tiny
                        fastSpeed => particleSpeed;
                    } else if (s1.sizeCategory == 0 && s2.sizeCategory == 0) {
                        // normal + normal
                        slowSpeed => particleSpeed;
                    } else {
                        // All other combinations
                        midSpeed => particleSpeed;
                    }

                    // Spawn particles
                    for (0 => int k; k < 10; k++) {
                        spawnParticle(collision_pos, collision_color, particleSpeed, particleLife);
                    }

                    // Sphere creation logic for specific collisions
                    if (collisionType == 0 &&
                        ((s1.isBlue == 1 && s2.isBlue == 0) || (s1.isBlue == 0 && s2.isBlue == 1)) &&
                        s1.shrinking == 0 && s2.shrinking == 0 &&
                        now - last_sphere_instantiation_time >= sphere_cooldown_duration) {

                        // Instantiate a smaller blue sphere at collision position
                        Sphere @ newSphere;
                        new Sphere @=> newSphere;
                        s1.scale * 0.6 * 0.8 => float newSize; // 40% smaller, then reduced by 20%
                        newSphere.init(collision_pos, 1, newSize, 1); // Color=1(blue), size=newSize, sizeCategory=1 (small)
                        spheres << newSphere;

                        // Play looping sound for the new sphere
                        playLoopingSound(newSphere);

                        // Play bubble sound
                        spork ~ playBubbleSound();

                        // Update last instantiation time
                        now => last_sphere_instantiation_time;
                    } else if (collisionType == 3) {
                        // Mixed size collisions
                        // Handle small blue + normal yellow creating a tiny blue sphere
                        if (((s1.isBlue == 1 && s1.sizeCategory == 1 && s2.isBlue == 0 && s2.sizeCategory == 0) ||
                             (s1.isBlue == 0 && s1.sizeCategory == 0 && s2.isBlue == 1 && s2.sizeCategory == 1)) &&
                            now - last_sphere_instantiation_time >= sphere_cooldown_duration) {

                            Sphere @ newSphere;
                            new Sphere @=> newSphere;

                            // Determine the normal sphere's scale
                            float normalScale;
                            if (s1.sizeCategory == 0) {
                                s1.scale => normalScale;
                            } else {
                                s2.scale => normalScale;
                            }

                            normalScale * 0.4 * 0.8 => float newSize; // 60% smaller than normal sphere, then reduced by 20%
                            newSphere.init(collision_pos, 1, newSize, 2); // Color=1(blue), size=newSize, sizeCategory=2 (tiny)
                            spheres << newSphere;

                            // Play looping sound for the new sphere
                            playLoopingSound(newSphere);

                            // Play bubble sound
                            spork ~ playBubbleSound();

                            // Update last instantiation time
                            now => last_sphere_instantiation_time;
                        }
                    }
                }
            }

            // Check if ndCircle is active and if sphere is inside ndCircle
            if (ndCircle_active == 1) {
                // Calculate distance between sphere and ndCircle center
                Math.sqrt(Math.pow(s1.position.x - ndCircle_position.x, 2.0) + Math.pow(s1.position.y - ndCircle_position.y, 2.0)) => float dist_to_ndCircle;

                if (dist_to_ndCircle <= ndCircle_scale && s1.shrinking == 0) {
                    // Sphere is inside ndCircle, start shrinking
                    1 => s1.shrinking;
                    if (s1.soundPlayed == 0) {
                        spork ~ playDyingSound();
                        1 => s1.soundPlayed;
                    }
                    // Stop the looping sound
                    stopLoopingSound(s1);
                }
            }

            if (s1.shrinking == 0) {
                s1.target_position.x + Math.random2f(-0.01, 0.01) => s1.target_position.x;
                s1.target_position.y + Math.random2f(-0.01, 0.01) => s1.target_position.y;
            }

            easeInOutCubic(0.1) => float ease_factor;
            ease_factor * (s1.target_position.x - s1.position.x) * speedFactor + s1.position.x => s1.position.x;
            ease_factor * (s1.target_position.y - s1.position.y) * speedFactor + s1.position.y => s1.position.y;

            s1.position => s1.sphere_mesh.pos;

            // Scaling effect during first 0.5 seconds
            if (now - s1.spawn_time < 0.5::second) {
                ((now - s1.spawn_time) / 0.5::second) => float t;
                easeInOutCubic(t) => float scale_factor;
                s1.scale * scale_factor => s1.sphere_mesh.sca;
            } else if (s1.shrinking == 0) {
                s1.scale => s1.sphere_mesh.sca;
            }

            Math.sqrt(Math.pow(s1.position.x - circle_center.x, 2.0) + Math.pow(s1.position.y - circle_center.y, 2.0)) => float distanceFromCenter;

            if (distanceFromCenter > circle_size && s1.shrinking == 0) {
                1 => s1.shrinking;
                if (s1.soundPlayed == 0) {
                    spork ~ playDyingSound();
                    1 => s1.soundPlayed;
                }
                // Stop the looping sound
                stopLoopingSound(s1);
            }

            if (s1.shrinking == 1) {
                s1.scale - (dt * 0.5) => s1.scale;
                if (s1.scale <= 0.0) {
                    0.0 => s1.scale;
                    s1.scale => s1.sphere_mesh.sca;
                    s1.sphere_mesh.detach();
                    null @=> s1.sphere_mesh;
                    // Ensure the looping sound is stopped
                    stopLoopingSound(s1);
                    spheres.erase(i);
                    i--;
                    continue;
                }
                s1.scale => s1.sphere_mesh.sca;
            }
        }
    }
}

ParticleSystem ps;
ps.init(current_circle_size);

// Function to smoothly adjust the circle size using a cosine function
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    base_circle_size - ((base_circle_size - min_circle_size) / 2.0) * (1.0 + Math.cos(sin_time)) => current_circle_size;
    current_circle_size => ps.circle_size;
    center_circle_geo.build(current_circle_size, 64, 0.0, 2.0 * Math.PI); // Increased segments to 64
}

// Function to play bubble sound
fun void playBubbleSound() {
    SndBuf buffer => dac;

    // Load the sound file
    buffer.read("samples/bubble.wav");

    // Reset position to the beginning
    0 => buffer.pos;

    // Start playback
    1 => buffer.play;

    // Wait until the sound finishes
    buffer.length() => now;

    // Disconnect to clean up
    buffer =< dac;
}

// Function to play dying sound
fun void playDyingSound() {
    SndBuf buffer => dac;

    // Load the sound file
    buffer.read("samples/dying.wav");

    // Reset position to the beginning
    0 => buffer.pos;

    // Start playback
    1 => buffer.play;

    // Wait until the sound finishes
    buffer.length() => now;

    // Disconnect to clean up
    buffer =< dac;
}

// Declare variables for beat sound
SndBuf @ beatBuffer;
0 => int beatPlaying;

while (true) {
    GG.nextFrame() => now;
    // Update background time
    bg_time + GG.dt() => bg_time;

    // Calculate the sine of the angular frequency times time
    bg_omega * bg_time => float bg_angle;
    Math.sin(bg_angle) => float sin_value;

    // Map sine value from [-1,1] to [0,1] for brightness
    (sin_value + 1.0) / 2.0 => float brightness;

    // Set the background color using the calculated brightness
    @(brightness, brightness, brightness) => GG.scene().backgroundColor;


    if (GWindow.mouseLeft()) {
        if (now - last_spawn_time >= cooldown_duration) {
            GWindow.mousePos() => vec2 currentPos;
            GG.camera().screenCoordToWorldPos(currentPos, 2.0) => vec3 worldPos;

            for (0 => int j; j < 5; j++) {
                ps.spawnParticle(worldPos, start_color.val(), 0.6, 1.0);
            }

            Sphere @ s;
            new Sphere @=> s;
            // Randomly assign color
            (Math.random2f(0.0, 1.0) < 0.5) ? 1 : 0 => int color; // 1 for blue, 0 for yellow
            0.25 * 0.8 => float size; // Base size reduced by 20%
            0 => int category; // 0: normal
            s.init(worldPos, color, size, category);
            spheres << s;

            // Play looping sound for the new sphere
            playLoopingSound(s);

            // Play bubble sound
            spork ~ playBubbleSound();

            now => last_spawn_time;
        }
    }

    ps.update(GG.dt());
    ps.updateSpheres(GG.dt());
    updateCircleSize();

    // Natural Disaster Circle Logic
    if (ndCircle_active == 0 && now - last_ndCircle_time >= ndCircle_interval) {
        // Create a new ndCircle
        1 => ndCircle_active;
        now => ndCircle_start_time;
        now => last_ndCircle_time;
        Math.random2f(10.0, 20.0)::second => ndCircle_interval; // Set next interval

        // Set ndCircle size (at least 1/4 the size of envCircle)
        current_circle_size / 4.0 + Math.random2f(0.0, current_circle_size / 4.0) => ndCircle_size;

        // Random position within envCircle
        Math.random2f(0.0, 2.0 * Math.PI) => float angle;
        Math.random2f(0.0, (current_circle_size - ndCircle_size)) => float radius;
        circle_center.x + radius * Math.cos(angle) => ndCircle_position.x;
        circle_center.y + radius * Math.sin(angle) => ndCircle_position.y;
        nd_circle_z => ndCircle_position.z; // Set ndCircle z position

        // Initialize ndCircle geometry and mesh
        new CircleGeometry @=> ndCircle_geo;
        new FlatMaterial @=> ndCircle_material;
        new GMesh(ndCircle_geo, ndCircle_material) @=> ndCircle_mesh;
        ndCircle_mesh --> GG.scene();
        ndCircle_position => ndCircle_mesh.pos;
        ndCircle_size => ndCircle_scale; // Initialize ndCircle_scale
        ndCircle_scale => ndCircle_mesh.sca; // Set scale directly
        @(0.0, 0.0, 0.0) => ndCircle_material.color; // Set ndCircle color to black for visibility
        // add sfx here

        ndCircle_geo.build(1.0, 64, 0.0, 2.0 * Math.PI); // Build with unit size and increased segments
    }

    // Update ndCircle if active
    if (ndCircle_active == 1) {
        (now - ndCircle_start_time) / second => float ndCircle_elapsed;

        if (ndCircle_elapsed >= ndCircle_lifespan) {
            // ndCircle lifespan is over, remove ndCircle
            ndCircle_mesh.detach();
            null @=> ndCircle_mesh;
            null @=> ndCircle_geo;
            null @=> ndCircle_material;
            0 => ndCircle_active;
        } else {
            // Shrink ndCircle over ndCircle_shrink_duration
            ndCircle_size * (1.0 - ndCircle_elapsed / ndCircle_shrink_duration) => ndCircle_scale;
            if (ndCircle_scale < 0.0) {
                0.0 => ndCircle_scale;
            }
            ndCircle_scale => ndCircle_mesh.sca; // Set scale directly
        }
    }

    // Check the number of spheres and play beat sound if necessary
    if (spheres.size() >= 10 && beatPlaying == 0) {
        // Start playing beat
        new SndBuf @=> beatBuffer;
        beatBuffer.read("samples/beat.wav");
        beatBuffer.loop(1);
        beatBuffer => dac;
        beatBuffer.play();
        1 => beatPlaying;
    } else if (spheres.size() < 10 && beatPlaying == 1) {
        // Stop playing beat
        if (beatBuffer != null) {
            beatBuffer.rate(0);
            beatBuffer =< dac;
            null @=> beatBuffer;
        }
        0 => beatPlaying;
    }
}
