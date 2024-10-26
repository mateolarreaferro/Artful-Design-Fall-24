
// scene setup
GG.camera().orthographic();
0 * Color.DARKBLUE => GG.scene().backgroundColor;

// particle system parameters
UI_Float3 start_color(Color.SKYBLUE);
UI_Float3 end_color(Color.DARKPURPLE);
UI_Float lifetime(1.0);
UI_Float3 background_color(GG.scene().backgroundColor());

CircleGeometry particle_geo;

// pitch bank
//36, 48] @=> int pitches[];
Gain main_gain(1) => dac;

class Particle {
    // set up particle mesh
    FlatMaterial particle_mat;
    GMesh particle_mesh(particle_geo, particle_mat) --> GG.scene();
    0 => particle_mesh.sca;

    // particle properties
    @(0,1) => vec2 direction; // random direction
    time spawn_time;
    Color.WHITE => vec3 color;
}

512 => int PARTICLE_POOL_SIZE;
Particle particles[PARTICLE_POOL_SIZE];

class ParticleSystem {
    0 => int num_active;

    fun void update(float dt) {
        // update particles
        for (0 => int i; i < num_active; i++) {
            particles[i] @=> Particle p;

            // swap despawned particles to the end of the active list
            if (now - p.spawn_time >= lifetime.val()::second) {
                0 => p.particle_mesh.sca;
                num_active--;
                particles[num_active] @=> particles[i];
                p @=> particles[num_active];
                i--;
                //p.env.keyOff();
                continue;
            }

            // update particle
            {
                // update size (based on midi)
                // Std.ftom(p.osc.freq()) => float midi;
                //Math.remap(midi, 36, 48, 1, .1) => float size_factor;
                .5 => float size_factor;
                Math.pow((now - p.spawn_time) / lifetime.val()::second, .5) => float t;
                size_factor * (1 - t) => p.particle_mesh.sca;

                // update color
                p.color + (end_color.val() - p.color) * t => p.particle_mat.color;

                // update position
                (dt * p.direction).x => p.particle_mesh.translateX;
                (dt * p.direction).y => p.particle_mesh.translateY;
            }
        }
    }

    fun void spawnParticle(vec3 pos) {
        if (num_active < PARTICLE_POOL_SIZE) {
            particles[num_active] @=> Particle p;
            
            // audio mapping
            // pitches[Math.random2(0, pitches.size()-1)] + 12 => int midi;
            // Std.mtof(midi) => p.osc.freq;
            // p.env.keyOn();

            // map color 
            .5 => float color_factor;
            start_color.val() + (end_color.val() - start_color.val()) * color_factor => p.particle_mat.color;
            p.particle_mat.color() => p.color;

            // set random direction
            Math.random2f(0, 2 * Math.PI) => float random_angle;
            @(Math.cos(random_angle), Math.sin(random_angle)) => p.direction;

            now => p.spawn_time;
            pos => p.particle_mesh.pos;
            num_active++;
        }
    }
}

ParticleSystem ps;
while (true) {
    GG.nextFrame() => now;

    if (GWindow.mouseLeft()) {
    // Get the mouse position and convert to world coordinates
    GWindow.mousePos() => vec2 currentPos;
    GG.camera().screenCoordToWorldPos(currentPos, 2.0) => vec3 worldPos;

    // Spawn a particle at the mouse position
    ps.spawnParticle(worldPos);

    // Create the sphere at the clicked location
    GSphere sph --> GG.scene();
    .3 => sph.sca;
    worldPos => sph.pos; // Set the sphere's position 
    }

    ps.update(GG.dt());
    
}