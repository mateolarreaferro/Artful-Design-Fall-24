// Scene setup
GG.camera().orthographic();
0.3 * Color.WHITE => GG.scene().backgroundColor;

// Particle system parameters
UI_Float3 start_color(Color.SKYBLUE);
UI_Float3 end_color(Color.DARKPURPLE);
UI_Float lifetime(1.0);
UI_Float3 background_color(GG.scene().backgroundColor());
CircleGeometry particle_geo;

0.5::second => dur cooldown_duration;
now => time last_spawn_time;

// Create a centered circle in the middle of the screen
CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

// Build the circle geometry using the correct parameters
center_circle_geo.build(3, 32, 0.0, 2 * Math.PI); // radius, segments, thetaStart, thetaLength

// Set the material color (white color)
Color.WHITE => center_circle_material.color;

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

// Sphere class definition
class Sphere {
    GSphere @ sphere_mesh; // Sphere's visual mesh (reference)
    vec3 position;

    // Initialize a Sphere
    fun void init(vec3 pos) {
        new GSphere @=> sphere_mesh; // Allocate a new GSphere and assign it to the reference
        sphere_mesh --> GG.scene();
        0.15 => sphere_mesh.sca;
        pos => position;
        pos => sphere_mesh.pos;
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
                Math.random2f(0.1, 1.0) => float size_factor;
                Math.pow(((now - p.spawn_time) / second) / lifetime.val(), 0.5) => float t;
                size_factor * (1 - t) => p.particle_mesh.sca;

                // Update color
                p.color + (end_color.val() - p.color) * t => p.particle_mat.color;

                // Update position using translateX and translateY
                (dt * p.direction).x => p.particle_mesh.translateX;
                (dt * p.direction).y => p.particle_mesh.translateY;
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

    // Update the Brownian motion for spheres
    fun void updateSpheres(float dt) {
        for (0 => int i; i < spheres.size(); i++) {
            spheres[i] @=> Sphere @ s;

            // Apply a small random movement to simulate Brownian motion
            Math.random2f(-0.02, 0.02) +=> s.position.x;
            Math.random2f(-0.02, 0.02) +=> s.position.y;

            // Update the sphere's position
            s.position => s.sphere_mesh.pos;
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

            // Spawn a particle at the mouse position
            ps.spawnParticle(worldPos);

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
