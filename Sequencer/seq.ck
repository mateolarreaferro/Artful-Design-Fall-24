// Scene setup
GG.camera().orthographic();
@(0.847, 0.788, 0.608) => GG.scene().backgroundColor; // Ecru background

// Particle system parameters
UI_Float3 start_color(@(0.643, 0.141, 0.231)); // Start color: Amaranth Purple
UI_Float3 end_color(@(0.847, 0.592, 0.235));   // End color: Butterscotch
UI_Float lifetime(1.0);
UI_Float3 background_color(GG.scene().backgroundColor());
CircleGeometry particle_geo;

0.25::second => dur cooldown_duration;
now => time last_spawn_time;

// Create a centered circle in the middle of the screen
3 => float circle_radius; // Circle radius
vec3 circle_center; // Circle center position
circle_center.set(0.0, 0.0, 0.0); // Initialize components

CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Build the circle geometry using the correct parameters
center_circle_geo.build(circle_radius, 32, 0.0, 2 * Math.PI); // radius, segments, thetaStart, thetaLength

// Set the material color to Alloy Orange (converted to RGB)
@(0.741, 0.388, 0.184) => center_circle_material.color;

// Particle class definition
class Particle {
    // Set up particle mesh
    FlatMaterial particle_mat;
    GMesh particle_mesh(particle_geo, particle_mat) --> GG.scene();
    0 => particle_mesh.sca;

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

        // Randomly assign color between Amaranth Purple and Butterscotch
        if (Math.random2f(0, 1) < 0.5) {
            @(0.643, 0.141, 0.231) => sphere_mesh.color; // Amaranth Purple
        } else {
            @(0.847, 0.592, 0.235) => sphere_mesh.color; // Butterscotch
        }
    }
}

// Store the instantiated spheres as an array of references
Sphere @ spheres[0]; // Initialized as an empty array

// ParticleSystem class definition
class ParticleSystem {
    0 => int num_active;

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

    // Spawn a new particle
    fun void spawnParticle(vec3 pos) {
        if (num_active < PARTICLE_POOL_SIZE) {
            particles[num_active] @=> Particle p;

            // Set initial color
            0.5 => float color_factor;
            start_color.val() + (end_color.val() - start_color.val()) * color_factor => p.particle_mat.color;
            p.particle_mat.color() => p.color;

            // Set random direction
            Math.random2f(0, 2 * Math.PI) => float random_angle;
            Math.cos(random_angle) => p.direction.x;
            Math.sin(random_angle) => p.direction.y;

            now => p.spawn_time;
            pos => p.particle_mesh.pos;
            num_active++;
        }
    }

    // Update the Brownian motion for spheres with easing
    fun void updateSpheres(float dt) {
        for (0 => int i; i < spheres.size(); i++) {
            spheres[i] @=> Sphere @ s;

            // Update the sphere's target position with a smaller, smoother change
            if (s.shrinking == 0) {
                s.target_position.x + Math.random2f(-0.01, 0.01) => s.target_position.x;
                s.target_position.y + Math.random2f(-0.01, 0.01) => s.target_position.y;
            }

            // Use easing function for smoother transition and apply global speed factor
            easeInOutCubic(0.1) => float ease_factor;
            ease_factor * (s.target_position.x - s.position.x) * speedFactor + s.position.x => s.position.x;
            ease_factor * (s.target_position.y - s.position.y) * speedFactor + s.position.y => s.position.y;

            // Update the sphere's position
            s.position => s.sphere_mesh.pos;

            // Calculate distance from the center
            Math.sqrt(Math.pow(s.position.x - circle_center.x, 2) + Math.pow(s.position.y - circle_center.y, 2)) => float distance;

            // Check if the sphere is outside the circle
            if (distance > circle_radius && s.shrinking == 0) {
                1 => s.shrinking; // Start shrinking
            }

            // Handle shrinking
            if (s.shrinking == 1) {
                // Reduce the scale over time
                s.scale - (dt * 0.05) => s.scale; // Adjust the shrinking speed as needed
                if (s.scale <= 0) {
                    0 => s.scale;
                    s.scale => s.sphere_mesh.sca;
                    // Detach the sphere from the scene graph
                    s.sphere_mesh.detach();
                    // Nullify the sphere's mesh reference
                    null @=> s.sphere_mesh;
                    // Remove the sphere from the array
                    spheres.erase(i);
                    i--; // Adjust the index after removal
                    continue;
                }
                s.scale => s.sphere_mesh.sca;
            }
        }
    }
}

// Initialize the particle system
ParticleSystem ps;

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
                ps.spawnParticle(worldPos);
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
}
