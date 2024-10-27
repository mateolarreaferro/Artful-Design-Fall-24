// Scene setup
GG.camera().orthographic();
@(1.0, 0.063, 0.122) => GG.scene().backgroundColor; // Red background

// Bloom effect setup
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity; // Bloom intensity
0.6 => bloom_pass.radius;    // Bloom radius
0.3 => bloom_pass.threshold; // Bloom threshold

// Particle system parameters
UI_Float3 start_color(@(1.0, 0.063, 0.122)); // Start color: Red
UI_Float3 end_color(@(1.0, 0.063, 0.122));   // End color: Red (same color)
UI_Float3 collision_color(@(0.0, 1.0, 0.0)); // Collision-triggered color: Green
UI_Float lifetime(2.0);
UI_Float3 background_color(GG.scene().backgroundColor());
CircleGeometry particle_geo;

0.2::second => dur cooldown_duration;
now => time last_spawn_time;

// Create a centered circle in the middle of the screen
3 => float base_circle_size;    // Base size of the circle (initial size)
base_circle_size => float current_circle_size;  // Current size to track
0.3 * base_circle_size => float min_circle_size; // 40% smaller target size
0.0 => float sin_time;  // Time variable for the sine function
0.1 => float sin_speed; // Speed of the sine function change

vec3 circle_center; // Circle center position
circle_center.set(0.0, 0.0, 0.0); // Initialize components

// Create the static frame circle (slightly larger than the base circle)
1.02 * base_circle_size => float frame_circle_size; // 10% larger than the base size
CircleGeometry frame_circle_geo;
FlatMaterial frame_circle_material;
GMesh frame_circle_mesh(frame_circle_geo, frame_circle_material) --> GG.scene();

// Build the static frame circle
frame_circle_geo.build(frame_circle_size, 32, 0.0, 2 * Math.PI); // radius, segments, thetaStart, thetaLength

// Set the material color for the frame circle to black
@(0.0, 0.0, 0.0) => frame_circle_material.color;

// Create the dynamic inner circle (which will be rendered on top)
CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Build the inner circle geometry using the correct parameters
center_circle_geo.build(current_circle_size, 32, 0.0, 2 * Math.PI); // radius, segments, thetaStart, thetaLength

// Set the material color for the inner circle to make it more visible (e.g., a light gray)
@(0.8, 0.8, 0.8) => center_circle_material.color;

// Ensure the moving circle is added to the scene after the static frame circle
center_circle_mesh --> GG.scene();

// Particle class definition
class Particle {
    // Set up particle mesh
    FlatMaterial particle_mat;
    GMesh particle_mesh(particle_geo, particle_mat) --> GG.scene();
    0.1 => particle_mesh.sca; // Ensure particles are visible initially

    // Particle properties
    vec2 direction;
    time spawn_time;
    vec3 color;
}

128 => int PARTICLE_POOL_SIZE;
Particle particles[PARTICLE_POOL_SIZE];

// Ease-in-out cubic function
fun float easeInOutCubic(float t) {
    return (t < 0.5) ? (4 * t * t * t) : (1 - Math.pow(-2 * t + 2, 3) / 2);
}

// Global speed factor to control movement speed of all spheres
10 => float speedFactor;

// Sphere class definition
class Sphere {
    GSphere @ sphere_mesh;
    vec3 position;
    vec3 target_position;
    float scale;
    int shrinking;

    // Initialize a Sphere
    fun void init(vec3 pos) {
        new GSphere @=> sphere_mesh;
        sphere_mesh --> GG.scene();
        0.25 => scale => sphere_mesh.sca;
        pos => position;
        pos => sphere_mesh.pos;
        pos => target_position; // Initial target position is the same
        0 => shrinking;

        // Randomly assign color between Lapis Lazuli and Hunyadi Yellow
        if (Math.random2f(0, 1) < 0.5) {
            sphere_mesh.color(@(0.2, 0.396, 0.541)); // Lapis Lazuli
        } else {
            sphere_mesh.color(@(0.965, 0.682, 0.176)); // Hunyadi Yellow
        }
    }
}

// Store the instantiated spheres as an array of references
Sphere @ spheres[0]; // Initialized as an empty array

// ParticleSystem class definition
class ParticleSystem {
    0 => int num_active;
    float circle_size; // Track current circle size

    // Constructor to initialize with the current circle size
    fun void init(float currentSize) {
        currentSize => circle_size;
    }

    // Update particles
    fun void update(float dt) {
        for (0 => int i; i < num_active; i++) {
            particles[i] @=> Particle p;

            // Despawn particles that have exceeded their lifetime
            if (now - p.spawn_time >= lifetime.val()::second) {
                0 => p.particle_mesh.sca;
                num_active--;
                particles[num_active] @=> particles[i];
                p @=> particles[num_active];
                i--;
                continue;
            }

            // Update particle properties
            {
                // Update size
                0.5 => float size_factor;
                Math.pow(((now - p.spawn_time) / second) / lifetime.val(), 0.5) => float t;
                size_factor * (1 - t) => p.particle_mesh.sca;

                // Update color
                p.color + (end_color.val() - p.color) * t => p.particle_mat.color;

                // Update position using translateX and translateY smoothly
                (dt * p.direction).x * 0.6 => p.particle_mesh.translateX;
                (dt * p.direction).y * 0.6 => p.particle_mesh.translateY;
            }
        }
    }

    // Spawn a new particle with a specified color
    fun void spawnParticle(vec3 pos, vec3 color) {
        if (num_active < PARTICLE_POOL_SIZE) {
            particles[num_active] @=> Particle p;

            color => p.particle_mat.color;
            color => p.color;

            // Set random direction
            Math.random2f(0, 2 * Math.PI) => float random_angle;
            Math.cos(random_angle) => p.direction.x;
            Math.sin(random_angle) => p.direction.y;

            now => p.spawn_time;
            pos => p.particle_mesh.pos;
            num_active++;
        }
    }

    // Update the Brownian motion for spheres with easing and detect collisions
    fun void updateSpheres(float dt) {
        // Collision detection
        for (0 => int i; i < spheres.size(); i++) {
            spheres[i] @=> Sphere @ s1;
            
            for (i + 1 => int j; j < spheres.size(); j++) {
                spheres[j] @=> Sphere @ s2;

                // Calculate distance between the centers of the spheres
                Math.sqrt(Math.pow(s1.position.x - s2.position.x, 2) + Math.pow(s1.position.y - s2.position.y, 2)) => float distance;
                
                // Make collision detection stricter (require closer distance)
                if (distance <= (s1.scale + s2.scale) * 0.8) { // Adjusted threshold to be stricter
                    // Spawn collision-triggered particles at the midpoint of the colliding spheres
                    vec3 collision_pos;
                    (s1.position + s2.position) / 2 => collision_pos;

                    for (0 => int k; k < 10; k++) {
                        spawnParticle(collision_pos, collision_color.val()); // Use collision color
                    }
                }
            }

            // Update the sphere's target position with a smaller, smoother change
            if (s1.shrinking == 0) {
                s1.target_position.x + Math.random2f(-0.01, 0.01) => s1.target_position.x;
                s1.target_position.y + Math.random2f(-0.01, 0.01) => s1.target_position.y;
            }

            // Use easing function for smoother transition and apply global speed factor
            easeInOutCubic(0.1) => float ease_factor;
            ease_factor * (s1.target_position.x - s1.position.x) * speedFactor + s1.position.x => s1.position.x;
            ease_factor * (s1.target_position.y - s1.position.y) * speedFactor + s1.position.y => s1.position.y;

            // Update the sphere's position
            s1.position => s1.sphere_mesh.pos;

            // Calculate distance from the center
            Math.sqrt(Math.pow(s1.position.x - circle_center.x, 2) + Math.pow(s1.position.y - circle_center.y, 2)) => float distanceFromCenter;

            // Check if the sphere is outside the circle
            if (distanceFromCenter > circle_size && s1.shrinking == 0) {
                1 => s1.shrinking; // Start shrinking
            }

            // Handle shrinking
            if (s1.shrinking == 1) {
                // Reduce the scale over time
                s1.scale - (dt * 0.5) => s1.scale; // Adjust the shrinking speed as needed
                if (s1.scale <= 0) {
                    0 => s1.scale;
                    s1.scale => s1.sphere_mesh.sca;
                    // Detach the sphere from the scene graph
                    s1.sphere_mesh.detach();
                    // Nullify the sphere's mesh reference
                    null @=> s1.sphere_mesh;
                    // Remove the sphere from the array
                    spheres.erase(i);
                    i--; // Adjust the index after removal
                    continue;
                }
                s1.scale => s1.sphere_mesh.sca;
            }
        }
    }
}

// Initialize the particle system with the current circle size
ParticleSystem ps;
ps.init(current_circle_size);

// Function to smoothly adjust the circle size using a sine function
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    
    // Calculate the new circle size based on the sine function
    base_circle_size - ((base_circle_size - min_circle_size) / 2) * (1 + Math.sin(sin_time)) => current_circle_size;

    // Update ParticleSystem with the new circle size
    current_circle_size => ps.circle_size;

    // Rebuild the dynamic inner circle geometry with the new size
    center_circle_geo.build(current_circle_size, 32, 0.0, 2 * Math.PI);
}

// Main loop
while (true) {
    GG.nextFrame() => now;

    if (GWindow.mouseLeft()) {
        if (now - last_spawn_time >= cooldown_duration) {
            // Get the mouse position and convert to world coordinates
            GWindow.mousePos() => vec2 currentPos;
            GG.camera().screenCoordToWorldPos(currentPos, 2.0) => vec3 worldPos;

            // Spawn 5 particles at the mouse position
            for (0 => int j; j < 5; j++) {
                ps.spawnParticle(worldPos, start_color.val());
            }

            // Create a new Sphere instance with Brownian motion
            Sphere @ s;
            new Sphere @=> s;
            s.init(worldPos);
            spheres << s; // Add the Sphere reference to the list

            // Update the last spawn time
            now => last_spawn_time;
        }
    }

    // Update particle system and Brownian motion for spheres
    ps.update(GG.dt());
    ps.updateSpheres(GG.dt());

    // Update the dynamic circle size
    updateCircleSize();
}
