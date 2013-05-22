// USING BETA VERSION OF MINIM!!

import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;

Minim minim;
AverageListener audio;

void setupMinim() {
  minim = new Minim(this);
  audio = new AverageListener();
}

class AverageListener implements AudioListener {
  public AudioInput in;     // audio input
  public FFT fft;           // FFT 
  public BeatDetect beat;   // beat detect

    public color COLOR;
  public int BASS, MIDS, TREB, RED, GREEN, BLUE;

  private boolean gotBeat = false, gotMode = false, gotKinect = false;

  private int last_update = millis();
  public int BPM = 0;
  public int bpm_count = 0, sec_count = 0;
  private int[] bpms = new int [15];
  AudioSpectrum[] averageSpecs, fullSpecs;
  AudioSpectrum volume;

  AverageListener() {
    in = minim.getLineIn(Minim.MONO, 512);           // create the audio in 
    in.mute();                                       // mute it
    in.addListener(this);                            // add this object to listen to the audio in
    fft = new FFT(in.bufferSize(), in.sampleRate()); // create the FFT
    fft.logAverages(63, 1);                          // config the averages 
    fft.window(FFT.HAMMING);                         // shape the FFT buffer window using the HANN method
    beat = new BeatDetect();                         // create a new beat detect 
    beat.setSensitivity(280);                        // set it's sensitivity

    averageSpecs = new AudioSpectrum [ fft.avgSize() ];
    fullSpecs = new AudioSpectrum [ fft.specSize() ];
    for (int i = 0; i < averageSpecs.length; i++) averageSpecs[i] = new AudioSpectrum();
    for (int i = 0; i < fullSpecs.length; i++) fullSpecs[i] = new AudioSpectrum();

    volume = new AudioSpectrum();

    COLOR = color(0);
    BASS  = 0;
    MIDS  = 0;
    TREB  = 0;
    RED   = 0;
    GREEN = 0;
    BLUE  = 0;

    for (int i = 0; i < bpms.length; i++) bpms[i] = 0;
  }

  private void mapSpectrums() {
    for ( int i = 0; i < averageSpecs.length; i++) averageSpecs[i].set( fft.getAvg(i) );
    for ( int i = 0; i < fullSpecs.length; i++) fullSpecs[i].set( fft.getBand(i) );
    volume.set( in.mix.level()*100 );
  }

  private void mapRanges() {
    BASS = round(( averageSpecs[0].value + averageSpecs[1].value ) / 2);
    MIDS = round(( averageSpecs[2].value + averageSpecs[3].value ) / 2);
    TREB = round(( averageSpecs[4].value + averageSpecs[5].value ) / 2);
  }

  private void mapColors() {
    RED   = round(map(( averageSpecs[0].value + averageSpecs[1].value ) / 2, 0, 100, 0, 255));
    GREEN = round(map(( averageSpecs[2].value + averageSpecs[3].value ) / 2, 0, 100, 0, 255));
    BLUE  = round(map(( averageSpecs[4].value + averageSpecs[5].value ) / 2, 0, 100, 0, 255)); 

    COLOR = color(RED, GREEN, BLUE);
  }

  private void mapBPM() {

    // do we have a beat?
    if ( beat.isOnset() ) {
      bpm_count++; 
      gotBeat = true; 
      gotMode = true; 
      gotKinect = true;
    }

    int check = millis();
    if (check - last_update > 1000) {
      if (sec_count == bpms.length) {
        sec_count = 0;
      }
      bpms[sec_count] = bpm_count;
      sec_count++;

      BPM = 0;
      for (int i = 0; i < bpms.length; i++) BPM += bpms[i];
      BPM *= 4;

      bpm_count = 0;
      last_update = check;
    }
  }

  boolean isOnBeat() {
    if ( gotBeat ) {
      gotBeat = false;
      return true;
    } else return false;
  }

  boolean isOnMode() {
    if ( gotMode ) {
      gotMode = false;
      return true;
    } else return false;
  }

  boolean isOnKinect() {
    if ( gotKinect ) {
      gotKinect = false;
      return true;
    } else return false;
  }

  void close() {
    in.close();
  }

  void update() {
    fft.forward(in.mix.toArray());
    beat.detect(in.mix.toArray());
    mapSpectrums();
    mapRanges();
    mapColors();
    mapBPM();
  }

  void samples(float[] samps) {
    update();
  }

  void samples(float[] sampsL, float[] sampsR) {
    update();
  }
}

class AudioSpectrum {
  final int FRAME_TRIGGER      = 60; // how many frames must the peak and low values 

  float raw_peak = 0;    // the peak or max level of the spectrum
  float max_peak = 0;
  float raw_base = 9999;    // the base or lowest level of the spectrum
  float raw    = 0;    // the raw level of the spectrum

  float dB = 0; 
  float spectrumGain = 1.5;

  int value = 0;
  int peak = 0;

  int peak_count = 0, smooth_count = 0;  // counters for peak, base, and smooth

  int gray = 0;

  boolean lowerPeak = false;  // are we lowering the peak?

  AudioSpectrum() {
  }

  void set(float v) {

    raw = v * spectrumGain; // set raw

    float peak_check = max(raw_peak, raw); // get the max peak level
    if (peak_check < 1) peak_check = 1;

    raw_base = min(raw_base, raw);             // set the min base level

    if (peak_check == raw_peak) peak_count++; // if peak is the same as last time, inc the peak counter

    raw_peak = peak_check;  // now that we know if its the same or not, set it
    max_peak = max(max_peak, raw_peak);

    if (peak_count > FRAME_TRIGGER) {  // is our peak count higher the the trigger?
      lowerPeak = true; // start trying to lower the peak
      peak_count = 0;   // and reset the peak counter
    }

    if (lowerPeak == true && raw < raw_peak) { // should we lower the peak?
      raw_peak -= 0.5;
    } else if (lowerPeak == true && raw >= raw_peak) { // should we stop trying to lower the peak?
      lowerPeak = false;
    }

    dB = 20*((float)Math.log10(raw)); 

    gray  = int(map(raw, 0, max_peak, 0, 255));
    gray  = int(constrain(gray, 0, 255));

    value = int(map(raw, 0, max_peak, 0, 100));
    value = int(constrain(value, 0, 100));

    peak  = int(map(raw_peak, 0, max_peak, 0, 100));
    peak = int(constrain(peak, 0, 100));

    raw_base += 0.25; // keep trying to raise the base level a small amount every loop 
    max_peak -= 0.05;
    if (max_peak < 24) max_peak = 24;
  }
}

