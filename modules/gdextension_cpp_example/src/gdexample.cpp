#include "gdexample.h"
#include <godot_cpp/core/class_db.hpp>
#include <unistd.h>
#include "wiiuse.h"                 /* for wiimote_t, classic_ctrl_t, etc */
//#include <unistd.h>

using namespace godot;

void GDExample::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_amplitude"), &GDExample::get_amplitude);
	ClassDB::bind_method(D_METHOD("set_amplitude", "p_amplitude"), &GDExample::set_amplitude);
	ClassDB::add_property("GDExample", PropertyInfo(Variant::FLOAT, "amplitude"), "set_amplitude", "get_amplitude");

	ClassDB::bind_method(D_METHOD("connect_wii"), &GDExample::connect_wii);
	
}

GDExample::GDExample() {
	// Initialize any variables here.
	time_passed = 0.0;
	amplitude = 10.0;
}

GDExample::~GDExample() {
	// Add your cleanup here.
}

void GDExample::_process(double delta) {
	time_passed += delta;

	Vector2 new_position = Vector2(
		amplitude + (amplitude * sin(time_passed * 2.0)),
		amplitude + (amplitude * cos(time_passed * 1.5))
	);

	set_position(new_position);
}

void GDExample::connect_wii() {
	wiimote** wiimotes;
	int found, connected;

	/*
	 *	Initialize an array of wiimote objects.
	 *
	 *	The parameter is the number of wiimotes I want to create.
	 */
	wiimotes =  wiiuse_init(MAX_WIIMOTES);

	/*
	 *	Find wiimote devices
	 *
	 *	Now we need to find some wiimotes.
	 *	Give the function the wiimote array we created, and tell it there
	 *	are MAX_WIIMOTES wiimotes we are interested in.
	 *
	 *	Set the timeout to be 5 seconds.
	 *
	 *	This will return the number of actual wiimotes that are in discovery mode.
	 */
	found = wiiuse_find(wiimotes, MAX_WIIMOTES, 5);

	if (!found) {
		std::cout << "No wiimotes found." << std::endl;
		return ;
	}

	/*
	 *	Connect to the wiimotes
	 *
	 *	Now that we found some wiimotes, connect to them.
	 *	Give the function the wiimote array and the number
	 *	of wiimote devices we found.
	 *
	 *	This will return the number of established connections to the found wiimotes.
	 */
	connected = wiiuse_connect(wiimotes, MAX_WIIMOTES);

	if (connected) {
		std::cout << "Connected to " << connected << " wiimotes (of " << found << " found)." << std::endl;
	} else {
		std::cout << "Failed to connect to any wiimote." << std::endl;
		return ;
	}

	/*
	 *	Now set the LEDs and rumble for a second so it's easy
	 *	to tell which wiimotes are connected (just like the wii does).
	 */
	wiiuse_set_leds(wiimotes[0], WIIMOTE_LED_1);
	wiiuse_set_leds(wiimotes[1], WIIMOTE_LED_2);
	wiiuse_set_leds(wiimotes[2], WIIMOTE_LED_3);
	wiiuse_set_leds(wiimotes[3], WIIMOTE_LED_4);
	wiiuse_rumble(wiimotes[0], 1);
	wiiuse_rumble(wiimotes[1], 1);

#ifndef WIIUSE_WIN32
	usleep(200000);
#else
	Sleep(200);
#endif

	wiiuse_rumble(wiimotes[0], 0);
	wiiuse_rumble(wiimotes[1], 0);

	std::cout << "\nControls:" << std::endl;
	std::cout << "\tB toggles rumble." << std::endl;
	std::cout << "\t+ to start Wiimote accelerometer reporting, - to stop" << std::endl;
	std::cout << "\tUP to start IR camera (sensor bar mode), DOWN to stop." << std::endl;
	std::cout << "\t1 to start Motion+ reporting, 2 to stop." << std::endl;
	std::cout << "\n\n";

	/*
	 *	Maybe I'm interested in the battery power of the 0th
	 *	wiimote.  This should be WIIMOTE_ID_1 but to be sure
	 *	you can get the wiimote associated with WIIMOTE_ID_1
	 *	using the wiiuse_get_by_id() function.
	 *
	 *	A status request will return other things too, like
	 *	if any expansions are plugged into the wiimote or
	 *	what LEDs are lit.
	 */
	/* wiiuse_status(wiimotes[0]); */

	/*
	 *	This is the main loop
	 *
	 *	wiiuse_poll() needs to be called with the wiimote array
	 *	and the number of wiimote structures in that array
	 *	(it doesn't matter if some of those wiimotes are not used
	 *	or are not connected).
	 *
	 *	This function will set the event flag for each wiimote
	 *	when the wiimote has things to report.
	 */
	while (true) {
		if (wiiuse_poll(wiimotes, MAX_WIIMOTES)) {
			/*
			 *	This happens if something happened on any wiimote.
			 *	So go through each one and check if anything happened.
			 */
			int i = 0;
			std::cout << "\n\n--- POLLING [wiimotes " << connected << "] ---" << std::endl;
			for (; i < MAX_WIIMOTES; ++i) {
				switch (wiimotes[i]->event) {
					case WIIUSE_EVENT:
						// print someting
						std::cout << "wii event" << std::endl;
						
					default:
						break;
				}
			}
		}
	}

	/*
	 *	Disconnect the wiimotes
	 */
	wiiuse_cleanup(wiimotes, MAX_WIIMOTES);
	return ;
}


void GDExample::set_amplitude(const double p_amplitude) {
	amplitude = p_amplitude;
}

double GDExample::get_amplitude() const {
	return amplitude;
}

