// Set up the camera and background color
GG.camera().orthographic();
@(1.0, 0.063, 0.122) => GG.scene().backgroundColor;

GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1.0 => bloom_pass.intensity;
0.1 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

UI_Float3 start_color(@(1.0, 0.063, 0.122));
UI_Float3 end_color(@(1.0, 0.063, 0.122));
UI_Float lifetime(2.0);
UI_Float3 background_color(GG.scene().backgroundColor());
CircleGeometry particle_geo;

0.2::second => dur cooldown_duration;
now => time last_spawn_time;

3 => float base_circle_size;
base_circle_size => float current_circle_size;
0.3 * base_circle_size => float min_circle_size;
0.0 => float sin_time;
0.1 => float sin_speed;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

1.02 * base_circle_size => float frame_circle_size;
CircleGeometry frame_circle_geo;
FlatMaterial frame_circle_material;
GMesh frame_circle_mesh(frame_circle_geo, frame_circle_material) --> GG.scene();

frame_circle_geo.build(frame_circle_size, 32, 0.0, 2 * Math.PI);
@(0.0, 0.0, 0.0) => frame_circle_material.color;

CircleGeometry center_circle_geo;
FlatMaterial center_circle_material;
GMesh center_circle_mesh(center_circle_geo, center_circle_material) --> GG.scene();

center_circle_geo.build(current_circle_size, 32, 0.0, 2 * Math.PI);
@(0.8, 0.8, 0.8) => center_circle_material.color;

// Define colors
@(0.2, 0.396, 0.541) => vec3 blue_color;
@(0.965, 0.682, 0.176) => vec3 yellow_color;
@(0.5, 0.0, 0.5) => vec3 purple_color;
@(1.0, 0.0, 1.0) => vec3 pink_color;
@(0.0, 1.0, 0.0) => vec3 green_color;

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
    return (t < 0.5) ? (4 * t * t * t) : (1 - Math.pow(-2 * t + 2, 3) / 2);
}

10 => float speedFactor;

class Sphere {
    GSphere @ sphere_mesh;
    vec3 position;
    vec3 target_position;
    float scale;
    int shrinking;
    int isBlue;
    int sizeCategory; // 0: normal, 1: small, 2: tiny

    // Modified init function to accept color and size category
    fun void init(vec3 pos, int color, float size, int category) {
        new GSphere @=> sphere_mesh;
        sphere_mesh --> GG.scene();
        size => scale => sphere_mesh.sca;
        pos => position;
        pos => sphere_mesh.pos;
        pos => target_position;
        0 => shrinking;
        category => sizeCategory;

        if (color == 1) {
            sphere_mesh.color(blue_color); // Blue
            1 => isBlue;
        } else {
            sphere_mesh.color(yellow_color); // Yellow
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
                0.3 * (1 - Math.pow(((now - p.spawn_time) / second) / particle_lifetime, 0.2)) => p.particle_mesh.sca;
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

            color => p.particle_mat.color;
            color => p.color;

            Math.random2f(0, 2 * Math.PI) => float random_angle;
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

                Math.sqrt(Math.pow(s1.position.x - s2.position.x, 2) + Math.pow(s1.position.y - s2.position.y, 2)) => float distance;

                if (distance <= (s1.scale + s2.scale) * 0.8) {
                    vec3 collision_pos;
                    (s1.position + s2.position) / 2 => collision_pos;

                    // Determine collision type
                    int collisionType;
                    if (s1.sizeCategory == s2.sizeCategory) {
                        s1.sizeCategory => collisionType; // 0: normal-normal, 1: small-small, 2: tiny-tiny
                    } else {
                        3 => collisionType; // Mixed sizes
                    }

                    vec3 collision_color;
                    0 => int collisionColorSet; // Flag to indicate if collision_color has been set

                    0.6 => float particleSpeed;
                    1.0 => float particleLife;

                    // Set collision color and particle properties based on collision type and spheres' properties
                    if (collisionType == 0) {
                        // Normal Sphere Collision
                        0.6 => particleSpeed;
                        1.0 => particleLife;
                        if ((s1.isBlue == 1 && s2.isBlue == 0) || (s1.isBlue == 0 && s2.isBlue == 1)) {
                            blue_color => collision_color;
                            1 => collisionColorSet;
                        } else if (s1.isBlue == 1 && s2.isBlue == 1) {
                            yellow_color => collision_color;
                            1 => collisionColorSet;
                        } else if (s1.isBlue == 0 && s2.isBlue == 0) {
                            yellow_color => collision_color;
                            1 => collisionColorSet;
                        }
                    } else if (collisionType == 1 || collisionType == 2) {
                        // Small-Small or Tiny-Tiny Collisions
                        if (collisionType == 1) {
                            1.0 => particleSpeed;
                            0.5 => particleLife;
                        } else {
                            1.5 => particleSpeed;
                            0.25 => particleLife;
                        }
                        if (s1.isBlue == 1 && s2.isBlue == 1) {
                            purple_color => collision_color;
                            1 => collisionColorSet;
                        }
                    }

                    if (collisionColorSet == 1) {
                        for (0 => int k; k < 10; k++) {
                            spawnParticle(collision_pos, collision_color, particleSpeed, particleLife);
                        }
                    }

                    // Sphere creation logic for specific collisions
                    if (collisionType == 0 &&
                        ((s1.isBlue == 1 && s2.isBlue == 0) || (s1.isBlue == 0 && s2.isBlue == 1)) &&
                        s1.shrinking == 0 && s2.shrinking == 0 &&
                        now - last_sphere_instantiation_time >= sphere_cooldown_duration) {

                        // Instantiate a smaller blue sphere at collision position
                        Sphere @ newSphere;
                        new Sphere @=> newSphere;
                        s1.scale * 0.6 => float newSize; // 40% smaller
                        newSphere.init(collision_pos, 1, newSize, 1); // Color=1(blue), size=newSize, sizeCategory=1 (small)
                        spheres << newSphere;

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

                            normalScale * 0.4 => float newSize; // 60% smaller than normal sphere
                            newSphere.init(collision_pos, 1, newSize, 2); // Color=1(blue), size=newSize, sizeCategory=2 (tiny)
                            spheres << newSphere;

                            // Update last instantiation time
                            now => last_sphere_instantiation_time;
                        }
                    }
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

            Math.sqrt(Math.pow(s1.position.x - circle_center.x, 2) + Math.pow(s1.position.y - circle_center.y, 2)) => float distanceFromCenter;

            if (distanceFromCenter > circle_size && s1.shrinking == 0) {
                1 => s1.shrinking;
            }

            if (s1.shrinking == 1) {
                s1.scale - (dt * 0.5) => s1.scale;
                if (s1.scale <= 0) {
                    0 => s1.scale;
                    s1.scale => s1.sphere_mesh.sca;
                    s1.sphere_mesh.detach();
                    null @=> s1.sphere_mesh;
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
    base_circle_size - ((base_circle_size - min_circle_size) / 2) * (1 + Math.cos(sin_time)) => current_circle_size;
    current_circle_size => ps.circle_size;
    center_circle_geo.build(current_circle_size, 32, 0.0, 2 * Math.PI);
}

while (true) {
    GG.nextFrame() => now;

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
            (Math.random2f(0, 1) < 0.5) ? 1 : 0 => int color; // 1 for blue, 0 for yellow
            0.25 => float size; // Base size
            0 => int category; // 0: normal
            s.init(worldPos, color, size, category);
            spheres << s;

            now => last_spawn_time;
        }
    }

    ps.update(GG.dt());
    ps.updateSpheres(GG.dt());
    updateCircleSize();
}
