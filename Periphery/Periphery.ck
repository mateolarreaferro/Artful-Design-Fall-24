//-----------------------------------------------------------------------------
// name: Periphery.ck (Modified as requested)
//-----------------------------------------------------------------------------

// Set up the camera and background
GG.camera().orthographic();
@(0.992, 0.807, 0.388) => GG.scene().backgroundColor; 

// Set up render passes
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

1 => bloom_pass.intensity;
0.1 => bloom_pass.radius;
0.5 => bloom_pass.threshold;

// Variables for background color modulation
0 => float bg_time; 
(2.0 * Math.PI) / 60.0 => float bg_omega; 

// Z-position for background circles
-0.5 => float bg_circle_z;

// Define vibrant colors
new vec3[0] @=> vec3 vibrant_colors[];
vibrant_colors << @(0.976, 0.643, 0.376);  
vibrant_colors << @(0.992, 0.807, 0.388);  
vibrant_colors << @(0.357, 0.525, 0.761);

// Variables for circles
(3 * 0.8) => float base_circle_size; 
(base_circle_size * 0.3) => float min_circle_size;
0.0 => float sin_time;
0.5 => float sin_speed; // fixed sin_speed

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

0.0 => float env_circle_z;

// Text
GText text --> GG.scene();
text.sca(.2);
text.text("inhale");

// limitCircle - its size is affected by scrolling
min_circle_size => float limit_circle_size;
CircleGeometry limitCircle_geo;
FlatMaterial limitCircle_material;
GMesh limitCircle_mesh(limitCircle_geo, limitCircle_material) --> GG.scene();
@(0.357, 0.525, 0.761) => limitCircle_material.color;
limitCircle_geo.build(limit_circle_size, 100, 0.0, 2.0 * Math.PI);
@(circle_center.x, circle_center.y, env_circle_z) => limitCircle_mesh.pos;

// breathingCircle
CircleGeometry breathingCircle_geo;
FlatMaterial breathingCircle_material;
GMesh breathingCircle_mesh(breathingCircle_geo, breathingCircle_material) --> GG.scene();
@(circle_center.x, circle_center.y, env_circle_z) => breathingCircle_mesh.pos;
@(0.992, 0.807, 0.388) => breathingCircle_material.color; 
base_circle_size => float current_circle_size;
current_circle_size => float previous_circle_size;
1 => int was_increasing; 

// textCircle - make it smaller than min_circle_size, for example half:
CircleGeometry textCircle_geo;
FlatMaterial textCircle_material;
GMesh textCircle_mesh(textCircle_geo, textCircle_material) --> GG.scene();
@(0, 0, 0) => textCircle_material.color;
// Here we scale down by half:
textCircle_geo.build(min_circle_size * 0.6, 100, 0.0, 2.0 * Math.PI);
@(circle_center.x, circle_center.y, env_circle_z) => textCircle_mesh.pos;

// Update breathingCircle size
fun void updateCircleSize() {
    sin_time + (sin_speed * GG.dt()) => sin_time;
    limit_circle_size => float max_circle_size;
    max_circle_size - ((max_circle_size - min_circle_size * 0.6) / 2.0) * (1.0 + Math.cos(sin_time)) => current_circle_size;
    breathingCircle_geo.build(current_circle_size, 100, 0.0, 2.0 * Math.PI);

    int is_increasing;
    if (current_circle_size > previous_circle_size) {
        1 => is_increasing;
    } else if (current_circle_size < previous_circle_size) {
        0 => is_increasing;
    } else {
        is_increasing => is_increasing;
    }

    if (is_increasing != was_increasing) {
        if (is_increasing == 1) {
            text.text("inhale");
        } else {
            text.text("exhale");
        }
        is_increasing => was_increasing;
    }

    current_circle_size => previous_circle_size;
}

// Initialize Mouse
Mouse mouse;
spork ~ mouse.selfUpdate();

// Pads
GGen padGroup --> GG.scene();
4 => int NUM_PADS;
GPad pads[NUM_PADS];

for (0 => int i; i < NUM_PADS; i++) {
    new GPad @=> pads[i];
}

// Resize listener
fun void resizeListener() {
    WindowResizeEvent e;  
    while (true) {
        e => now;  
        placePads();
    }
} spork ~ resizeListener();

fun void placePads() {
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    GG.camera().viewSize() => float frustrumHeight;
    frustrumHeight * aspect => float frustrumWidth;

    frustrumHeight / NUM_PADS => float padSpacing;
    for (0 => int i; i < NUM_PADS; i++) {
        pads[i] @=> GPad pad;
        pad.init(mouse, i);
        pad --> padGroup;
        pad.sca(padSpacing * 0.4);

        float pY;
        (padSpacing * i - frustrumHeight / 2.0 + padSpacing / 2.0) => pY;
        pY => pad.posY;

        float pX;
        (-frustrumWidth / 2.0 + padSpacing * 0.4) => pX;
        pX => pad.posX;
    }
    padGroup.posX(0);
}

class GPad extends GGen {
    GPlane pad --> this;
    FlatMaterial mat;
    pad.mat(mat);

    Mouse @ mouse;
    int index;

    0 => static int NONE;
    1 => static int HOVERED;
    2 => static int ACTIVE;
    0 => int state;

    0 => static int MOUSE_HOVER;
    1 => static int MOUSE_EXIT;
    2 => static int MOUSE_CLICK;

    [Color.BLACK, Color.ORANGE, Color.WHITE] @=> vec3 colorMap[];

    new GMesh[5] @=> GMesh bg_circle_meshes[];
    new CircleGeometry[5] @=> CircleGeometry bg_circle_geometries[];
    new FlatMaterial[5] @=> FlatMaterial bg_circle_materials[];
    new float[5] @=> float bg_circle_target_sizes[];
    new float[5] @=> float bg_circle_current_sizes[];
    new float[5] @=> float bg_circle_growth_speeds[];
    new vec3[5] @=> vec3 bg_circle_colors[];
    new float[5] @=> float bg_circle_speeds[];
    new int[5] @=> int is_shrinking[];

    SndBuf @ sampleBuf;
    float volume;
    float targetVolume;
    float volumeStep;
    1.5 => float fadeTime;

    fun void init(Mouse @ m, int idx) {
        if (mouse != null) return;
        m @=> this.mouse;
        idx => this.index;
        spork ~ this.clickListener();

        null @=> sampleBuf;
        0.0 => volume;
        0.0 => targetVolume;
        0.0 => volumeStep;

        spork ~ this.selfUpdate();
    }

    fun void color(vec3 c) {
        mat.color(c);
    }

    fun int isHovered() {
        vec3 worldScale;
        pad.scaWorld() => worldScale;  
        float halfWidth; worldScale.x / 2.0 => halfWidth;
        float halfHeight; worldScale.y / 2.0 => halfHeight;
        vec3 worldPos;
        pad.posWorld() => worldPos;    

        if (mouse.worldPos.x > worldPos.x - halfWidth && mouse.worldPos.x < worldPos.x + halfWidth &&
            mouse.worldPos.y > worldPos.y - halfHeight && mouse.worldPos.y < worldPos.y + halfHeight) {
            return true;
        }
        return false;
    }

    fun void pollHover() {
        if (isHovered()) {
            handleInput(MOUSE_HOVER);
        } else {
            if (state == HOVERED) handleInput(MOUSE_EXIT);
        }
    }

    fun void clickListener() {
        while (true) {
            GG.nextFrame() => now;
            if (GWindow.mouseLeftDown() && isHovered()) {
                handleInput(MOUSE_CLICK);
            }
        }
    }

    fun void selfUpdate() {
        while (true) {
            this.update(GG.dt());
            GG.nextFrame() => now;
        }
    }

    fun void handleInput(int input) {
        if (state == NONE) {
            if (input == MOUSE_HOVER) {
                enter(HOVERED);
            } else if (input == MOUSE_CLICK) {
                enter(ACTIVE);
                instantiateCircles();
                startSample();
            }
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT) {
                enter(NONE);
            } else if (input == MOUSE_CLICK) {
                if (state == ACTIVE) {
                    enter(NONE);
                    shrinkCircles();
                    stopSample();
                } else {
                    enter(ACTIVE);
                    instantiateCircles();
                    startSample();
                }
            }
        } else if (state == ACTIVE) {
            if (input == MOUSE_CLICK) {
                enter(NONE);
                shrinkCircles();
                stopSample();
            }
        }
    }

    fun void enter(int s) {
        s => state;
    }

    fun void update(float dt) {
        pollHover();
        this.color(colorMap[state]);

        float newScale;
        pad.scaX() + (0.05 * (1.0 - pad.scaX())) => newScale;
        newScale => pad.sca;

        if (state == ACTIVE) {
            for (0 => int i; i < bg_circle_meshes.size(); i++) {
                if (is_shrinking[i] == 0 && bg_circle_meshes[i] != null) {
                    float growSize;
                    (bg_circle_current_sizes[i] + (bg_circle_growth_speeds[i] * (bg_circle_target_sizes[i] - bg_circle_current_sizes[i]))) => growSize;
                    growSize => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(growSize, 64, 0.0, 2.0 * Math.PI);
                }
            }
        }

        for (0 => int i; i < bg_circle_meshes.size(); i++) {
            if (is_shrinking[i] == 1 && bg_circle_meshes[i] != null) {
                float shrinkSize;
                (bg_circle_current_sizes[i] - (0.05 * bg_circle_target_sizes[i])) => shrinkSize;
                if (shrinkSize <= 0.0) {
                    bg_circle_meshes[i].detach();
                    null @=> bg_circle_meshes[i];
                    null @=> bg_circle_geometries[i];
                    null @=> bg_circle_materials[i];
                    0 => is_shrinking[i];
                } else {
                    shrinkSize => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(shrinkSize, 72, 0.0, 2.0 * Math.PI);
                }
            }
        }

        if (sampleBuf != null) {
            if (volume != targetVolume) {
                volume + (volumeStep * dt) => volume;
                if (volume > 1.0) { 1.0 => volume; }
                if (volume < 0.0) { 0.0 => volume; }
                if ((volumeStep > 0 && volume >= targetVolume) || (volumeStep < 0 && volume <= targetVolume)) {
                    targetVolume => volume;
                    if (volume == 0.0) {
                        sampleBuf =< dac;
                        null @=> sampleBuf;
                    }
                }
            }
            if (sampleBuf != null) {
                volume => sampleBuf.gain;
            }
        }
    }

    fun void instantiateCircles() {
        for (0 => int i; i < 5; i++) {
            float circle_size; Std.rand2f(0.5, 1.5) => circle_size;
            float initial_size; 0.0 => initial_size;

            float x_pos; Std.rand2f(-5.0, 5.0) => x_pos;
            float y_pos; Std.rand2f(-5.0, 5.0) => y_pos;

            float growth_speed; Std.rand2f(0.02, 0.1) => growth_speed;
            growth_speed => bg_circle_growth_speeds[i];

            vibrant_colors.size() => int num_colors;
            int color_index; Std.rand2(0, num_colors - 1) => color_index;
            vec3 circle_color;
            vibrant_colors[color_index] => circle_color;
            circle_color => bg_circle_colors[i];

            new CircleGeometry @=> bg_circle_geometries[i];
            bg_circle_geometries[i].build(initial_size, 72, 0.0, 2.0 * Math.PI);

            new FlatMaterial @=> bg_circle_materials[i];
            circle_color => bg_circle_materials[i].color;

            new GMesh(bg_circle_geometries[i], bg_circle_materials[i]) @=> bg_circle_meshes[i];
            bg_circle_meshes[i] --> GG.scene();

            bg_circle_z => float z_pos;
            @(x_pos, y_pos, z_pos) => bg_circle_meshes[i].pos;

            circle_size => bg_circle_target_sizes[i];
            initial_size => bg_circle_current_sizes[i];
            0 => is_shrinking[i];
        }
    }

    fun void shrinkCircles() {
        for (0 => int i; i < bg_circle_meshes.size(); i++) {
            if (bg_circle_meshes[i] != null && is_shrinking[i] == 0) {
                1 => is_shrinking[i];
            }
        }
    }

    fun void startSample() {
        if (sampleBuf == null) {
            new SndBuf @=> sampleBuf;
            sampleBuf => dac;
            string filename;

            if (index == 0) {
                "samples/Nature.wav" => filename;
                0.6 => targetVolume;
            } else if (index == 1) {
                "samples/Rain.wav" => filename;
                0.2 => targetVolume;
            } else if (index == 2) {
                "samples/Beat.wav" => filename;
                0.3 => targetVolume;
            } else if (index == 3) {
                "samples/Drone.wav" => filename;
                1.0 => targetVolume;
            } else {
                return;
            }

            sampleBuf.read(filename);
            sampleBuf.loop(1);
            0.0 => sampleBuf.gain;
            sampleBuf.play();
            0.0 => volume;
            (targetVolume - volume) / fadeTime => volumeStep;
        } else {
            0 => sampleBuf.pos;
            0.0 => volume;
            if (index == 0) {
                0.6 => targetVolume;
            } else if (index == 1) {
                0.2 => targetVolume;
            } else if (index == 2) {
                0.3 => targetVolume;
            } else if (index == 3) {
                1.0 => targetVolume;
            } else {
                return;
            }
            (targetVolume - volume) / fadeTime => volumeStep;
        }
    }

    fun void stopSample() {
        if (sampleBuf != null) {
            sampleBuf.gain() => volume;
            0.0 => targetVolume;
            (targetVolume - volume) / fadeTime => volumeStep;
        }
    }
}

class Mouse {
    vec3 worldPos;

    fun void selfUpdate() {
        while (true) {
            GG.nextFrame() => now;
            GG.camera().screenCoordToWorldPos(GWindow.mousePos(), 1.0) => worldPos;
        }
    }
}

fun float vec3Distance(vec3 a, vec3 b) {
    return Math.sqrt((a.x - b.x)*(a.x - b.x) +
                     (a.y - b.y)*(a.y - b.y) +
                     (a.z - b.z)*(a.z - b.z));
}

class Particle {
    GMesh @ mesh;
    CircleGeometry @ geometry;
    FlatMaterial @ material;
    vec3 position;
    vec3 velocity;
    vec3 color;
    float lifespan;
    float age;
    float size;
    int active;

    fun void init(vec3 pos, vec3 vel, vec3 col, float life, float s) {
        pos => position;
        vel => velocity;
        col => color;
        life => lifespan;
        0.0 => age;
        s => size;
        1 => active;

        new CircleGeometry @=> geometry;
        geometry.build(size, 32, 0.0, 2.0 * Math.PI);

        new FlatMaterial @=> material;
        material.color(col);

        new GMesh(geometry, material) @=> mesh;
        mesh --> GG.scene();
        position => mesh.pos;
    }

    fun void update(float dt) {
        age + dt => age;
        if (age < lifespan) {
            position + velocity * dt => position;
            position => mesh.pos;

            float distance_from_center;
            vec3Distance(position, circle_center) => distance_from_center;

            float max_distance; 20.0 => max_distance;
            if (distance_from_center > max_distance) {
                mesh.detach();
                null @=> mesh;
                null @=> geometry;
                null @=> material;
                0 => active;
                return;
            }

            float alpha; (1.0 - (age / lifespan)) => alpha;
            material.color(@(color.x * alpha, color.y * alpha, color.z * alpha));

            float new_size; (size * alpha) => new_size;
            geometry.build(new_size, 32, 0.0, 2.0 * Math.PI);
        } else {
            mesh.detach();
            null @=> mesh;
            null @=> geometry;
            null @=> material;
            0 => active;
        }
    }
}

64 => int MAX_PARTICLES;
Particle particles[MAX_PARTICLES];

for (0 => int i; i < MAX_PARTICLES; i++) {
    new Particle @=> particles[i];
    0 => particles[i].active;
}

fun void instantiateParticles() {
    for (0 => int i; i < 10; i++) {
        int idx; -1 => idx;
        for (0 => int j; j < MAX_PARTICLES; j++) {
            if (particles[j].active == 0) {
                j => idx;
                break;
            }
        }
        if (idx == -1) {
            break;
        }

        float size; Std.rand2f(0.05, 0.15) => size;
        float angle; Std.rand2f(0.0, 2.0 * Math.PI) => angle;

        float R1; (current_circle_size / 2.0 * 1.5) => R1;
        float R2; (current_circle_size / 2.0 * 2.0) => R2;
        float radius; Std.rand2f(R1, R2) => radius;

        float x_pos; (circle_center.x + radius * Math.cos(angle)) => x_pos;
        float y_pos; (circle_center.y + radius * Math.sin(angle)) => y_pos;
        float z_pos; circle_center.z => z_pos;
        vec3 position;
        @(x_pos, y_pos, z_pos) => position;

        float dx; (x_pos - circle_center.x) => dx;
        float dy; (y_pos - circle_center.y) => dy;
        float length; Math.sqrt(dx*dx + dy*dy) => length;
        float nx; (dx / length) => nx;
        float ny; (dy / length) => ny;

        float speed; 2.0 => speed;
        float vx; (nx * speed) => vx;
        float vy; (ny * speed) => vy;
        float vz; 0.0 => vz;
        vec3 velocity;
        @(vx, vy, vz) => velocity;

        vec3 color; @(0.0, 0.0, 0.0) => color;
        float lifespan; Std.rand2f(1.0, 2.0) => lifespan;

        particles[idx].init(position, velocity, color, lifespan, size);
    }
}

// Main loop
while (true) {
    GG.nextFrame() => now;

    bg_time + GG.dt() => bg_time;
    float bg_angle; (bg_omega * bg_time) => bg_angle;
    float sin_value; Math.sin(bg_angle) => sin_value;

    float scroll_delta; GWindow.scrollY() => scroll_delta;
    (limit_circle_size + (scroll_delta * 0.05)) => limit_circle_size;

    // Increase max limit to 3.0 * min_circle_size (instead of 2.0)
    if (limit_circle_size < min_circle_size) { min_circle_size => limit_circle_size; }
    if (limit_circle_size > 3.0 * min_circle_size) { (3.0 * min_circle_size) => limit_circle_size; }

    updateCircleSize();
    limitCircle_geo.build(limit_circle_size, 100, 0.0, 2.0 * Math.PI);

    placePads();

    for (0 => int i; i < MAX_PARTICLES; i++) {
        if (particles[i].active == 1) {
            particles[i].update(GG.dt());
        }
    }
}
