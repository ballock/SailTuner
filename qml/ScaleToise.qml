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

import QtQuick 2.0
import "."

/**
 * ScaleToise
 *
 * Display notes from scale, with current note centered.
 */

ToiseFlickable {
	id: scale

	// note
	property int note: 1
	// octave
	property int octave: 4

	// case colors
	property color colorAltered: "#40888888"
	property color colorNatural: "transparent"

	// Toise parameters
	index: note + NoteNames.nb * octave
	marks: NoteNames.notes
	nb_marks_displayed: width > 100 ? Math.min(nb_marks, width / theme.fontSizeLarge * 0.8) : 1

	mark_color: function(note) {
		if (isAltered(note)) return colorAltered;
		else return colorNatural;
	}

	function isAltered(i) {
		return (i < 4 && (i & 1)) || (i > 5 && !(i & 1))
	}

	// ToiseFlikcable parameters
	min: NoteNames.nb * 0 // ut 0
	max: NoteNames.nb * 9 - 1 // si 8

	onOctaveChanged: {
		if (!flik_enable) return
		index = note + NoteNames.nb * octave
		updateFlickable()
	}
}
