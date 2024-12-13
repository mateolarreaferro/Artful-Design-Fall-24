// Set up the camera and background
GG.camera().orthographic();

// Default scenario colors (when no pads are selected)
vec3 default_background_color;
default_background_color.set(0.992, 0.807, 0.388);

// Original vibrant colors
vec3 default_vibrant_colors[3];
default_vibrant_colors[0].set(0.976, 0.643, 0.376);
default_vibrant_colors[1].set(0.992, 0.807, 0.388);
default_vibrant_colors[2].set(0.357, 0.525, 0.761);

// Set initial background to default
default_background_color => GG.scene().backgroundColor;

// We'll store the currently used vibrant_colors in an array
vec3 vibrant_colors[3];
int i;
0 => i;
while(i < 3)
{
    default_vibrant_colors[i].x => float vx;
    default_vibrant_colors[i].y => float vy;
    default_vibrant_colors[i].z => float vz;
    vibrant_colors[i].set(vx, vy, vz);
    i + 1 => i;
}

// Define pad-specific color palettes
vec3 pad_background_colors[4];
pad_background_colors[0].set(0.2, 0.2, 0.2);        // Noise_Ambience
pad_background_colors[1].set(0.545, 0.270, 0.074);  // Cafe_Ambience
pad_background_colors[2].set(0.2, 0.4, 0.2);         // Forrest_Ambience
pad_background_colors[3].set(0.1, 0.1, 0.3);         // Drone_Ambience

// vibrant colors per pad
vec3 pad_vibrant_colors[4][3];
// Pad 0's colors:
pad_vibrant_colors[0][0].set(0.976, 0.643, 0.376);
pad_vibrant_colors[0][1].set(0.992, 0.807, 0.388);
pad_vibrant_colors[0][2].set(0.357, 0.525, 0.761);

// Pad 1's colors:
pad_vibrant_colors[1][0].set(0.8, 0.5, 0.2);
pad_vibrant_colors[1][1].set(0.9, 0.7, 0.4);
pad_vibrant_colors[1][2].set(0.7, 0.4, 0.1);

// Pad 2's colors:
pad_vibrant_colors[2][0].set(0.3, 0.6, 0.3);
pad_vibrant_colors[2][1].set(0.4, 0.7, 0.4);
pad_vibrant_colors[2][2].set(0.2, 0.5, 0.2);

// Pad 3's colors:
pad_vibrant_colors[3][0].set(0.2, 0.2, 0.5);
pad_vibrant_colors[3][1].set(0.3, 0.3, 0.6);
pad_vibrant_colors[3][2].set(0.4, 0.4, 0.7);

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

// Variables for circles
(3 * 0.8) => float base_circle_size; 
(base_circle_size * 0.3) => float min_circle_size;
0.0 => float sin_time;
0.5 => float sin_speed;

vec3 circle_center;
circle_center.set(0.0, 0.0, 0.0);

0.0 => float env_circle_z;

// Text
GText text --> GG.scene();
0.2 => float text_scale;
text.sca(text_scale);
text.text("inhale");

// limitCircle
min_circle_size => float limit_circle_size;
CircleGeometry limitCircle_geo;
FlatMaterial limitCircle_material;
GMesh limitCircle_mesh(limitCircle_geo, limitCircle_material) --> GG.scene();
limitCircle_material.color(@(0.357, 0.525, 0.761));
limitCircle_geo.build(limit_circle_size, 100, 0.0, 2.0 * Math.PI);
@(circle_center.x, circle_center.y, env_circle_z) => limitCircle_mesh.pos;

// breathingCircle
CircleGeometry breathingCircle_geo;
FlatMaterial breathingCircle_material;
GMesh breathingCircle_mesh(breathingCircle_geo, breathingCircle_material) --> GG.scene();
@(circle_center.x, circle_center.y, env_circle_z) => breathingCircle_mesh.pos;

// Set the breathingCircle color to match the background
breathingCircle_material.color(@(default_background_color.x, default_background_color.y, default_background_color.z));

base_circle_size => float current_circle_size;
current_circle_size => float previous_circle_size;
1 => int was_increasing; 

// textCircle
CircleGeometry textCircle_geo;
FlatMaterial textCircle_material;
GMesh textCircle_mesh(textCircle_geo, textCircle_material) --> GG.scene();
textCircle_material.color(@(0, 0, 0));
(min_circle_size * 0.6) => float text_circle_size;
textCircle_geo.build(text_circle_size, 100, 0.0, 2.0 * Math.PI);
@(circle_center.x, circle_center.y, env_circle_z) => textCircle_mesh.pos;

fun void updateCircleSize()
{
    limit_circle_size => float max_circle_size;
    (max_circle_size - (min_circle_size * 0.6)) / 2.0 => float amplitude;

    if (amplitude < 0.0001)
    { 
        0.0001 => amplitude; 
    }

    0.25 => float radius_rate;
    radius_rate / amplitude => float sin_speed;

    sin_time + (sin_speed * GG.dt()) => sin_time;

    max_circle_size - (amplitude * (1.0 + Math.cos(sin_time))) => current_circle_size;

    breathingCircle_geo.build(current_circle_size - 0.005, 100, 0.0, 2.0 * Math.PI);

    int is_increasing;
    if (current_circle_size > previous_circle_size)
    {
        1 => is_increasing;
    }
    else if (current_circle_size < previous_circle_size)
    {
        0 => is_increasing;
    }
    else
    {
        was_increasing => is_increasing;
    }

    if (is_increasing != was_increasing)
    {
        if (is_increasing == 1)
        {
            text.text("inhale");
        }
        else
        {
            text.text("exhale");
        }
        is_increasing => was_increasing;
    }

    current_circle_size => previous_circle_size;
}

class Mouse
{
    vec3 worldPos;

    fun void selfUpdate()
    {
        while (true)
        {
            GG.nextFrame() => now;
            GG.camera().screenCoordToWorldPos(GWindow.mousePos(), 1.0) => worldPos;
        }
    }
}

Mouse mouse;
spork ~ mouse.selfUpdate();

// Pads
GGen padGroup --> GG.scene();
4 => int NUM_PADS;
GPad pads[NUM_PADS];

int p;
0 => p;
while(p<NUM_PADS)
{
    new GPad @=> pads[p];
    p + 1 => p;
}

// Resize listener
fun void resizeListener()
{
    WindowResizeEvent e;  
    while (true)
    {
        e => now;  
        placePads();
    }
}
spork ~ resizeListener();

fun void placePads()
{
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    GG.camera().viewSize() => float frustrumHeight;
    frustrumHeight * aspect => float frustrumWidth;
    
    (frustrumHeight / NUM_PADS) => float padSpacing;
    float topPadY;
    (-frustrumHeight / 2.0 + padSpacing / 2.0) => topPadY;
    
    float vertical_gap;
    (padSpacing * 0.4) => vertical_gap; 
    
    int q;
    0 => q;
    while(q<NUM_PADS)
    {
        pads[q] @=> GPad pad;
        pad.init(mouse, q);
        pad --> padGroup;

        (padSpacing * 0.3) => pad.sca;
        
        float pY;
        if (q == 0)
        {
            topPadY => pY;
        }
        else
        {
            topPadY + (q * vertical_gap) => pY;
        }
        pY => pad.posY;
        
        float pX;
        (-frustrumWidth / 2.0 + padSpacing * 0.4) => pX;
        pX => pad.posX;

        q + 1 => q;
    }
    padGroup.posX(0);
}

class GPad extends GGen
{
    GPlane pad --> this;
    FlatMaterial mat;
    pad.mat(mat);

    Mouse @ mouse;
    int index;

    static int NONE;
    static int HOVERED;
    static int ACTIVE;

    0 => NONE;
    1 => HOVERED;
    2 => ACTIVE;

    0 => int state;

    static int MOUSE_HOVER;
    static int MOUSE_EXIT;
    static int MOUSE_CLICK;

    0 => MOUSE_HOVER;
    1 => MOUSE_EXIT;
    2 => MOUSE_CLICK;

    vec3 colorMap[3];

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
    
    static GPad @activePad;

    fun void init(Mouse @ m, int idx)
    {
        if (mouse != null) { return; }
        m @=> this.mouse;
        idx => this.index;
        spork ~ this.clickListener();

        null @=> sampleBuf;
        0.0 => volume;
        0.0 => targetVolume;
        0.0 => volumeStep;

        colorMap[0].set(0,0,0);       // NONE -> Black
        colorMap[1].set(1,0.65,0);    // HOVERED -> Orange
        colorMap[2].set(1,1,1);       // ACTIVE -> White

        spork ~ this.selfUpdate();
    }

    fun void color(vec3 c)
    {
        mat.color(c);
    }

    fun int isHovered()
    {
        vec3 worldScale;
        pad.scaWorld() => worldScale;  
        float halfWidth; worldScale.x / 2.0 => halfWidth;
        float halfHeight; worldScale.y / 2.0 => halfHeight;
        vec3 worldPos;
        pad.posWorld() => worldPos;    

        if (mouse.worldPos.x > worldPos.x - halfWidth && mouse.worldPos.x < worldPos.x + halfWidth &&
            mouse.worldPos.y > worldPos.y - halfHeight && mouse.worldPos.y < worldPos.y + halfHeight)
        {
            return 1;
        }
        return 0;
    }

    fun void pollHover()
    {
        if (isHovered() == 1)
        {
            handleInput(MOUSE_HOVER);
        }
        else
        {
            if (state == HOVERED) { handleInput(MOUSE_EXIT); }
        }
    }

    fun void clickListener()
    {
        while (true)
        {
            GG.nextFrame() => now;
            if (GWindow.mouseLeftDown() && isHovered() == 1)
            {
                handleInput(MOUSE_CLICK);
            }
        }
    }

    fun void selfUpdate()
    {
        while (true)
        {
            this.update(GG.dt());
            GG.nextFrame() => now;
        }
    }

    fun void handleInput(int input)
    {
        if (input == MOUSE_HOVER)
        {
            if (state == NONE)
            {
                enter(HOVERED);
            }
        }
        else if (input == MOUSE_EXIT)
        {
            if (state == HOVERED)
            {
                enter(NONE);
            }
        }
        else if (input == MOUSE_CLICK)
        {
            if (state == ACTIVE)
            {
                // deactivate
                enter(NONE);
                shrinkCircles();
                stopSample();
                if (GPad.activePad == this)
                {
                    null @=> GPad.activePad;
                    default_background_color => GG.scene().backgroundColor;
                    int c;
                    0 => c;
                    while(c<3)
                    {
                        default_vibrant_colors[c].x => float vx;
                        default_vibrant_colors[c].y => float vy;
                        default_vibrant_colors[c].z => float vz;
                        vibrant_colors[c].set(vx, vy, vz);
                        c + 1 => c;
                    }
                    breathingCircle_material.color(@(default_background_color.x, default_background_color.y, default_background_color.z));
                }
            }
            else
            {
                // activate this pad, deactivate others
                if (GPad.activePad != null && GPad.activePad != this)
                {
                    GPad.activePad.enter(NONE);
                    GPad.activePad.shrinkCircles();
                    GPad.activePad.stopSample();
                    null @=> GPad.activePad;
                }

                enter(ACTIVE);
                instantiateCircles();
                startSample();
                this @=> GPad.activePad;

                pad_background_colors[this.index] => GG.scene().backgroundColor;
                int c;
                0 => c;
                while(c<3)
                {
                    pad_vibrant_colors[this.index][c].x => float vx;
                    pad_vibrant_colors[this.index][c].y => float vy;
                    pad_vibrant_colors[this.index][c].z => float vz;
                    vibrant_colors[c].set(vx, vy, vz);
                    c + 1 => c;
                }

                breathingCircle_material.color(@(vibrant_colors[0].x, vibrant_colors[0].y, vibrant_colors[0].z));
            }
        }
    }

    fun void enter(int s)
    {
        s => state;
    }

    fun void update(float dt)
    {
        pollHover();
        this.color(colorMap[state]);

        float newScale;
        pad.scaX() + (0.05 * (1.0 - pad.scaX())) => newScale;
        newScale => pad.sca;

        int i;
        0 => i;
        if (state == ACTIVE)
        {
            while(i<bg_circle_meshes.size())
            {
                if (is_shrinking[i] == 0 && bg_circle_meshes[i] != null)
                {
                    float growSize;
                    (bg_circle_current_sizes[i] + (bg_circle_growth_speeds[i] * (bg_circle_target_sizes[i] - bg_circle_current_sizes[i]))) => growSize;
                    growSize => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(growSize, 100, 0.0, 2.0 * Math.PI);
                }
                i + 1 => i;
            }
        }

        0 => i;
        while(i<bg_circle_meshes.size())
        {
            if (is_shrinking[i] == 1 && bg_circle_meshes[i] != null)
            {
                float shrinkSize;
                (bg_circle_current_sizes[i] - (0.05 * bg_circle_target_sizes[i])) => shrinkSize;
                if (shrinkSize <= 0.0)
                {
                    bg_circle_meshes[i].detach();
                    null @=> bg_circle_meshes[i];
                    null @=> bg_circle_geometries[i];
                    null @=> bg_circle_materials[i];
                    0 => is_shrinking[i];
                }
                else
                {
                    shrinkSize => bg_circle_current_sizes[i];
                    bg_circle_geometries[i].build(shrinkSize, 100, 0.0, 2.0 * Math.PI);
                }
            }
            i + 1 => i;
        }

        if (sampleBuf != null)
        {
            if (volume != targetVolume)
            {
                volume + (volumeStep * dt) => volume;
                if (volume > 1.0) { 1.0 => volume; }
                if (volume < 0.0) { 0.0 => volume; }
                if ((volumeStep > 0 && volume >= targetVolume) || (volumeStep < 0 && volume <= targetVolume))
                {
                    targetVolume => volume;
                    if (volume == 0.0)
                    {
                        sampleBuf =< dac;
                        null @=> sampleBuf;
                    }
                }
            }
            if (sampleBuf != null)
            {
                volume => sampleBuf.gain;
            }
        }
    }

    fun void instantiateCircles()
    {
        int i;
        0 => i;
        while(i<5)
        {
            float circle_size; Std.rand2f(0.5, 1.5) => circle_size;
            float initial_size; 0.0 => initial_size;

            float x_pos; Std.rand2f(-5.0, 5.0) => x_pos;
            float y_pos; Std.rand2f(-5.0, 5.0) => y_pos;

            float growth_speed; Std.rand2f(0.02, 0.1) => growth_speed;
            growth_speed => bg_circle_growth_speeds[i];

            int num_colors; vibrant_colors.size() => num_colors;
            int color_index; Std.rand2(0, num_colors - 1) => color_index;
            vec3 circle_color;
            vibrant_colors[color_index] => circle_color;

            new CircleGeometry @=> bg_circle_geometries[i];
            bg_circle_geometries[i].build(initial_size, 100, 0.0, 2.0 * Math.PI);

            new FlatMaterial @=> bg_circle_materials[i];
            bg_circle_materials[i].color(@(circle_color.x, circle_color.y, circle_color.z));

            new GMesh(bg_circle_geometries[i], bg_circle_materials[i]) @=> bg_circle_meshes[i];
            bg_circle_meshes[i] --> GG.scene();

            bg_circle_z => float z_pos;
            @(x_pos, y_pos, z_pos) => bg_circle_meshes[i].pos;

            circle_size => bg_circle_target_sizes[i];
            initial_size => bg_circle_current_sizes[i];
            0 => is_shrinking[i];

            i + 1 => i;
        }
    }

    fun void shrinkCircles()
    {
        int i;
        0 => i;
        while(i<bg_circle_meshes.size())
        {
            if (bg_circle_meshes[i] != null && is_shrinking[i] == 0)
            {
                1 => is_shrinking[i];
            }
            i + 1 => i;
        }
    }

    fun void startSample()
    {
        if (sampleBuf == null)
        {
            new SndBuf @=> sampleBuf;
            sampleBuf => dac;
            string filename;

            if (index == 0)
            {
                "samples/Noise_Ambience.wav" => filename;
                1.0 => targetVolume;
            }
            else if (index == 1)
            {
                "samples/Cafe_Ambience.wav" => filename;
                1.0 => targetVolume;
            }
            else if (index == 2)
            {
                "samples/Forrest_Ambience.wav" => filename;
                1.0 => targetVolume;
            }
            else if (index == 3)
            {
                "samples/Drone_Ambience.wav" => filename;
                1.0 => targetVolume;
            }
            else
            {
                return;
            }

            sampleBuf.read(filename);
            sampleBuf.loop(1);
            0.0 => sampleBuf.gain;
            sampleBuf.play();
            0.0 => volume;
            (targetVolume - volume) / fadeTime => volumeStep;
        }
        else
        {
            0 => sampleBuf.pos;
            0.0 => volume;
            if (index == 0)
            {
                0.6 => targetVolume;
            }
            else if (index == 1)
            {
                0.2 => targetVolume;
            }
            else if (index == 2)
            {
                0.3 => targetVolume;
            }
            else if (index == 3)
            {
                1.0 => targetVolume;
            }
            else
            {
                return;
            }
            (targetVolume - volume) / fadeTime => volumeStep;
        }
    }

    fun void stopSample()
    {
        if (sampleBuf != null)
        {
            sampleBuf.gain() => volume;
            0.0 => targetVolume;
            (targetVolume - volume) / fadeTime => volumeStep;
        }
    }
}

fun float vec3Distance(vec3 a, vec3 b)
{
    return Math.sqrt((a.x - b.x)*(a.x - b.x) +
                     (a.y - b.y)*(a.y - b.y) +
                     (a.z - b.z)*(a.z - b.z));
}

class Particle
{
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

    fun void init(vec3 pos, vec3 vel, vec3 col, float life, float s)
    {
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
        material.color(@(col.x, col.y, col.z));

        new GMesh(geometry, material) @=> mesh;
        mesh --> GG.scene();
        position => mesh.pos;
    }

    fun void update(float dt)
    {
        age + dt => age;
        if (age < lifespan)
        {
            position + (velocity * dt) => position;
            position => mesh.pos;

            float distance_from_center;
            vec3Distance(position, circle_center) => distance_from_center;

            float max_distance; 20.0 => max_distance;
            if (distance_from_center > max_distance)
            {
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
        }
        else
        {
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

0 => i;
while(i<MAX_PARTICLES)
{
    new Particle @=> particles[i];
    0 => particles[i].active;
    i + 1 => i;
}

fun void instantiateParticles()
{
    int i;
    0 => i;
    while(i<10)
    {
        int idx; -1 => idx;
        int j;
        0 => j;
        while(j<MAX_PARTICLES)
        {
            if (particles[j].active == 0)
            {
                j => idx;
                break;
            }
            j + 1 => j;
        }
        if (idx == -1)
        {
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
        position.set(x_pos, y_pos, z_pos);

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
        velocity.set(vx, vy, vz);

        vec3 color;
        color.set(0.0, 0.0, 0.0);
        float lifespan; Std.rand2f(1.0, 2.0) => lifespan;

        particles[idx].init(position, velocity, color, lifespan, size);
        i + 1 => i;
    }
}

// Main loop
while (true)
{
    GG.nextFrame() => now;

    bg_time + GG.dt() => bg_time;
    float bg_angle; (bg_omega * bg_time) => bg_angle;
    float sin_value; Math.sin(bg_angle) => sin_value;

    float scroll_delta; GWindow.scrollY() => scroll_delta;
    limit_circle_size + (scroll_delta * 0.05) => limit_circle_size;

    if (limit_circle_size < min_circle_size) { min_circle_size => limit_circle_size; }
    if (limit_circle_size > 3.0 * min_circle_size) { (3.0 * min_circle_size) => limit_circle_size; }

    updateCircleSize();
    limitCircle_geo.build(limit_circle_size, 100, 0.0, 2.0 * Math.PI);

    placePads();

    0 => i;
    while (i<MAX_PARTICLES)
    {
        if (particles[i].active == 1)
        {
            particles[i].update(GG.dt());
        }
        i + 1 => i;
    }
}
