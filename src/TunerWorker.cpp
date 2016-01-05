/* Copyright 2016 (C) Louis-Joseph Fournier 
 * louisjoseph.fournier@gmail.com
 *
 * This file is part of SailTuner.
 *
 * SailTuner is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * SailTuner is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#include <QDBusConnection>
#include <QDBusInterface>

#include <iostream>
#include <fstream>
#include <stdint.h>

extern "C" {
#include <pulse/simple.h>
}

#include "TunerWorker.hpp"

#define name_(x) #x
#define name(x) name_(x)
#define NAME name(TARGET)

using namespace std;

/// file name to record audio

const char * TunerWorker::filename_record = NULL;

/// function to prevent screen blank on Sailfish OS

static void blank_prevent(bool prevent)
{
	cerr << __func__ << " " << prevent << endl;
	QDBusConnection system = QDBusConnection::connectToBus(QDBusConnection::SystemBus, "system");
	QDBusInterface interface("com.nokia.mce", "/com/nokia/mce/request", "com.nokia.mce.request", system);

	if (prevent) {
		interface.call(QLatin1String("req_display_blanking_pause"));
	} else {
		interface.call(QLatin1String("req_display_cancel_blanking_pause"));
	}
}

TunerWorker::TunerWorker() :
	running(false),
	quit(false),
	la_to_update(0),
	temperament_to_update(-1)
{
	//qRegisterMetaType<PitchDetection::PitchResult>("PitchDetection::PitchResult");
}

TunerWorker::~TunerWorker()
{
}

void TunerWorker::Start()
{
	cerr << __func__ << endl;
	mutex.lock();
	running = true;
	condition.wakeOne();
	mutex.unlock();
}

void TunerWorker::Stop()
{
	cerr << __func__ << endl;
	mutex.lock();
	running = false;
	mutex.unlock();
}

void TunerWorker::Quit()
{
	mutex.lock();
	running = false;
	quit = true;
	condition.wakeOne();
	mutex.unlock();
}

void TunerWorker::SetLa(double la)
{
	mutex.lock();
	la_to_update = la;
	mutex.unlock();
}

void TunerWorker::SetTemperamentIndex(int idx)
{
	mutex.lock();
	temperament_to_update = idx;
	mutex.unlock();
}

void TunerWorker::Entry()
{
	cerr << __func__ << endl;

	int nbSamplePreventBlanking = nbSecPreventBlanking * PitchDetection::rate;
	int nb_sample_running = 0;
	bool new_stream = true, waked;

	int16_t *buffer = new int16_t[nbSampleBuffer];

	PitchDetection::PitchResult result;

	ofstream *file = NULL;
	if (filename_record) file = new ofstream(filename_record);

	PitchDetection *pitchDetection = new PitchDetection();
	emit temperamentListUpdated(pitchDetection->GetTemperamentList());

	// pulseaudio
	pa_simple *p_simple = NULL;
	pa_sample_spec p_spec;

	p_spec.format = PA_SAMPLE_S16NE;
	p_spec.channels = 1;
	p_spec.rate = PitchDetection::rate;

	while (1) {
		// wait for running
		mutex.lock();
		if (!running) {
			blank_prevent(false);
			while (!running && !quit) {
				waked = condition.wait(&mutex, p_simple ? stopPulseAfterMs : ULONG_MAX);
				if (!waked && p_simple) {
					// stop pulseaudio after a delay if not running
					pa_simple_free(p_simple);
					p_simple = NULL;
				}
			}
			cerr << "wake-up" << endl;
			// reset operations on start
			new_stream = true;
		}
		if (quit) {
			mutex.unlock();
			break;
		}
		// update config
		if (la_to_update) {
			pitchDetection->SetLa(la_to_update);
			la_to_update = 0;
		}
		if (temperament_to_update != -1) {
			pitchDetection->SetTemperament(temperament_to_update);
			temperament_to_update = -1;
		}
		mutex.unlock();

		if (!p_simple) {
			// start pulseaudio if stopped
			p_simple = pa_simple_new(
					NULL,
					NAME,
					PA_STREAM_RECORD,
					NULL,
					"Mic",
					&p_spec,
					NULL,
					NULL,
					NULL
					);
		}
		else if (new_stream) {
			// flush pulseaudio if paused
			pa_simple_flush(p_simple, NULL);
		}

		// if srteam was stopped, reset analyse
		if (new_stream) {
			pitchDetection->Reset();
			nb_sample_running = 0;
			new_stream = false;
		}

		// get audio data
		int size = pa_simple_read(p_simple, (void*) buffer, nbSampleBuffer << 1, NULL);
		if (size < 0) {
			cerr << "audio read failed " << size << endl;
			continue;
		}
		//cerr << "read " << nb_sample_running << endl;

		// record in file is needed
		if (file) file->write((char*) buffer, nbSampleBuffer << 1);

		pitchDetection->AudioAnalyse(buffer, nbSampleBuffer);

		if (pitchDetection->GetResultUpdated(result)) {
			if (result.found) cout << Scale::NoteName(result.note) << " " << result.frequency << endl;
			emit resultUpdated(result);
		}

		// prevent screen blanking
		nb_sample_running += nbSampleBuffer;
		if (nb_sample_running >= nbSamplePreventBlanking && running) {
			nb_sample_running = 0;
			blank_prevent(true);
		}
	}

	if (p_simple) pa_simple_free(p_simple);

	delete pitchDetection;
	delete buffer;

	if (file) {
		file->close();
		delete file;
	}
}

/// Set a filename before instanciation to record raw audio stream

void TunerWorker::set_record(const char *f)
{
	filename_record = f;
}

