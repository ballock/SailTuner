import QtQuick 2.0

/**
 * Meter in half circle
 */

Item {
	/// current level
	property double level: 0.5 
	/// minimum level
	property double min: -50
	/// maximum level
	property double max: 50
	/// numbers to write on the scale
	property variant marks: [-40, -20, 0, 20, 40]
	/// marks regions colors
	property variant region_color: ["red", "yellow", "green", "yellow", "red"]
	/// theme object
	property QtObject theme

	property double r_circle_min: 0.85
	property double r_circle_max: 1

	property double amin: angle(min)
	property double amax: angle(max)

	/// positions helper functions
	function angle(level) {
		return (level - min) / (max - min) * Math.PI - Math.PI / 2
	}
	function getx(angle, k) {
		return width * 0.5 + width * 0.5 * k * Math.sin(angle)
	}
	function gety(angle, k) {
		// k: [0,1]
		return height - height * k * Math.cos(angle)
	}

	/// objects draw

	function arc(ctx, k) {
		ctx.beginPath()
		ctx.moveTo(getx(amin, k), gety(amin, k))
		for (var i = amin + 0.01; i <= amax; i+=0.01) {
			ctx.lineTo(getx(i,k), gety(i,k))
		}
		ctx.stroke()
	}

	function arc_part(ctx, k, a1, a2) {
		ctx.lineTo(getx(a1,k), gety(a1,k))
		var eps = 0.01
		if (a2 > a1) {
			for (var i = a1 + eps; i < a2; i+=eps) {
				ctx.lineTo(getx(i,k), gety(i,k))
			}
		}
		else {
			for (var i = a1 - eps; i > a2; i-=eps) {
				ctx.lineTo(getx(i,k), gety(i,k))
			}
		}
		ctx.lineTo(getx(a2,k), gety(a2,k))
	}

	function line_mark(ctx, value, r_min, r_max) {
		var a = angle(value)
		ctx.beginPath()
		ctx.moveTo(getx(a, r_min), gety(a, r_min))
		ctx.lineTo(getx(a, r_max), gety(a, r_max))
		ctx.stroke()
	}

	/// Ellipse
	Canvas {
		id: ellipse
		anchors.fill: parent

		property double r_text: 0.92

		property double l_marker: 0.035
		property double h_marker: 7
		property int font_size: 20

		onPaint: {
			var ctx = getContext('2d');
			ctx.strokeStyle = theme.primaryColor
			ctx.lineWidth = 1

			arc(ctx, r_circle_min)
			arc(ctx, r_circle_max)

			ctx.font = font_size + "px sans-serif"
			ctx.textAlign = "center"

			ctx.lineWidth = h_marker
			ctx.strokeStyle = theme.secondaryColor
			for (var i = 0; i < marks.length; i++) {
				line_mark(ctx, marks[i], r_circle_min - l_marker, r_circle_min + l_marker)
				var a = angle(marks[i])
				ctx.fillText(marks[i], getx(a, r_text), gety(a, r_text) + 4)
				ctx.strokeText()
			}

			// "beetween" marks
			ctx.lineWidth = 1
			ctx.strokeStyle = theme.primaryColor
			for (var i = 0; i < marks.length - 1; i++) {
				line_mark(ctx, (marks[i] + marks[i+1])/2, r_circle_min, r_circle_max)
			}
		}
	}

	Canvas {
		/// level arrow
		id: arrow
		anchors.fill: parent
		property double k: 0.82
		property double k_base: 0.1
		property double angle: parent.angle(level)

		onPaint: {
			var ctx = getContext('2d');
			ctx.clearRect(0,0,width,height)
			ctx.strokeStyle = theme.primaryColor
			ctx.lineWidth = 1
			ctx.beginPath()
			ctx.moveTo(getx(angle, k_base), gety(angle, k_base))
			ctx.lineTo(getx(angle, k), gety(angle, k))
			ctx.stroke()
		}
	}

	Canvas {
		/// region colors
		id: regions
		anchors.fill: parent
		z: -4
		onPaint: {
			var ctx = getContext('2d');
			ctx.clearRect(0,0,width,height)

			var l1 = min
			var l2

			for (var i = 0; i < marks.length; i++) {
				if (i == marks.length - 1) l2 = max
				else l2 = (marks[i] + marks[i+1]) / 2

				if (level <= l2) {
					var a1 = angle(l1)
					var a2 = angle(l2)
					ctx.fillStyle = region_color[i]
					ctx.beginPath()
					ctx.moveTo(getx(a1, r_circle_min), gety(a1, r_circle_min))
					arc_part(ctx, r_circle_min, a1, a2)
					arc_part(ctx, r_circle_max, a2, a1)
					ctx.lineTo(getx(a1, r_circle_min), gety(a1, r_circle_min))
					ctx.fill()
					break;
				}
				l1 = l2
			}
		}
	}

	Behavior on level {
		NumberAnimation {
			duration: 50
			easing.amplitude: max - min
		}
	}

	onLevelChanged: {
		arrow.requestPaint()
		regions.requestPaint()
	}

	MouseArea {
		anchors.fill: parent
		onClicked: {
			level = Math.random() * (max - min) + min
		}
	}	
}