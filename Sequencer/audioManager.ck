// Initialize the sound buffer and connect it to the digital-to-analog converter (DAC)
SndBuf buf => dac;

// Load your WAV file into the buffer
buf.read("samples/loop.wav");

// Set the playback rate (1.0 is normal speed)
1.0 => buf.rate;

// Enable looping
1 => buf.loop;

// Define the duration for playback (e.g., 10 seconds)
40::second => dur playTime;

// Start playback
buf.pos(0); // Ensure playback starts from the beginning

// Advance time by the specified duration
playTime => now;

// Stop playback by disconnecting the buffer
buf =< dac;
