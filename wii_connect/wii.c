/*
 *	wiiuse
 *
 *	Written By:
 *		Michael Laforest	< para >
 *		Email: < thepara (--AT--) g m a i l [--DOT--] com >
 *
 *	Copyright 2006-2007
 *
 *	This file is part of wiiuse.
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *	$Header$
 *
 */

/**
 *	@file
 *
 *	@brief Example using the wiiuse API.
 *
 *	This file is an example of how to use the wiiuse library.
 */

#include <stdio.h>                      /* for printf */
#include "wiiuse.h"                 /* for wiimote_t, classic_ctrl_t, etc */
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>
#include <X11/keysymdef.h>
#include <stdbool.h>
#include <cjson/cJSON.h>

#ifndef WIIUSE_WIN32
#include <unistd.h>                     /* for usleep */
#endif
#define MAX_WIIMOTES				4

Display *display;

#define PRODUCTION_MODE 0
#define DEBUG_MODE 1

#ifndef MODE
	#define MODE DEBUG_MODE
#endif

#define IS_DEBUG_MODE (MODE == DEBUG_MODE)

#define MAX_PLAYERS 4
#define MAX_BUTTONS 11

typedef struct {
    unsigned short button;
    const char* actions[MAX_PLAYERS];
	bool continuous;
} ButtonMapping;

ButtonMapping buttonMappings[MAX_BUTTONS] = {};


/**
 * Returns the macro for the given button string.
 * 
 * @param str The button string.
 * @return The macro for the given button string.
 */
short int get_macro_from_string(char *str) {
	if (strcmp(str, "WIIMOTE_BUTTON_RIGHT") == 0) {
		return WIIMOTE_BUTTON_RIGHT;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_LEFT") == 0) {
		return WIIMOTE_BUTTON_LEFT;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_UP") == 0) {
		return WIIMOTE_BUTTON_UP;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_DOWN") == 0) {
		return WIIMOTE_BUTTON_DOWN;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_ONE") == 0) {
		return WIIMOTE_BUTTON_ONE;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_TWO") == 0) {
		return WIIMOTE_BUTTON_TWO;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_A") == 0) {
		return WIIMOTE_BUTTON_A;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_B") == 0) {
		return WIIMOTE_BUTTON_B;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_PLUS") == 0) {
		return WIIMOTE_BUTTON_PLUS;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_MINUS") == 0) {
		return WIIMOTE_BUTTON_MINUS;
	}
	else if (strcmp(str, "WIIMOTE_BUTTON_HOME") == 0) {
		return WIIMOTE_BUTTON_HOME;
	}
	else {
		printf("Error: Unknown button: %s\n", str);
		return -1;
	}
}


/**
 * Loads the button mappings from a JSON file into the global buttonMappings array.
 * 
 * @return A pointer to the cJSON object representing the loaded JSON data, or NULL if an error occurs.
 */
cJSON* load_button_mappings() {

    FILE *fp = fopen("./buttonMapping.json", "r");
    if (fp == NULL) {
        printf("Error: Unable to open the file.\n");
        return NULL;
    }

    char buffer[1024 * 2];
    fread(buffer, 1, sizeof(buffer), fp);
    fclose(fp);

    cJSON *json = cJSON_Parse(buffer);
    if (json == NULL) {
        const char *error_ptr = cJSON_GetErrorPtr();
        if (error_ptr != NULL) {
            printf("Error: %s\n", error_ptr);
        }
        cJSON_Delete(json);
        return NULL;
    }

    // iterate through the array of button mappings
	for (int i = 0; i < cJSON_GetArraySize(json); i++) {
		cJSON *buttonMapping = cJSON_GetArrayItem(json, i);

		// get the button macro
		char * buttonString = cJSON_GetObjectItemCaseSensitive(buttonMapping, "button")->valuestring;
		unsigned short button = get_macro_from_string(buttonString);

		// get the continuous flag
		bool continuous = cJSON_GetObjectItemCaseSensitive(buttonMapping, "continuous")->valueint > 0;

		// get the key mapping for the players
		cJSON *keyMapping = cJSON_GetObjectItemCaseSensitive(buttonMapping, "keyMapping");
		char *actions[MAX_PLAYERS];
		int num_actions = cJSON_GetArraySize(cJSON_GetObjectItemCaseSensitive(buttonMapping, "keyMapping"));
		for (int j = 0; j < num_actions; j++) {
			actions[j] = cJSON_GetArrayItem(keyMapping, j)->valuestring;
		}

		// add the button mapping to the global array
		buttonMappings[i].button = button;
		for (int j = 0; j < num_actions; j++) {
			buttonMappings[i].actions[j] = actions[j];
		}
		buttonMappings[i].continuous = continuous;
	}

    // dont clean up the json object because we need the char * values

    return json;
}

/**
 * Prints the button mappings for each player.
 * This function iterates through the buttonMappings array and prints the button,
 * continuous flag, and actions for each player.
 */
void print_button_mappings() {
	for (int i = 0; i < MAX_BUTTONS; i++) {
		printf("button: %i\n", buttonMappings[i].button);
		printf("continuous: %i\n", buttonMappings[i].continuous);
		for (int j = 0; j < MAX_PLAYERS; j++) {
			printf("player %i: %s\n", j, buttonMappings[i].actions[j]);
		}
	}
}

/**
 * Returns the input for the given player and button.
 * 
 * @param playerID The player ID.
 * @param button The button.
 * @return The key input for the given player and button.
 */
const char* getInput(int playerID, unsigned short button) {
    if (playerID >= 1 && playerID <= MAX_PLAYERS) {
        for (int i = 0; i < MAX_BUTTONS; ++i) {
            if (buttonMappings[i].button == button) {
                return buttonMappings[i].actions[playerID - 1];
            }
        }
    }
    return "unknown_input";
}

void pressKey(const char *key) {
	if (IS_DEBUG_MODE){
		printf("pressing key: %s\n", key);
	}
	KeyCode keycode = XKeysymToKeycode(display, XStringToKeysym(key));
 	XTestFakeKeyEvent(display, keycode, True, 0);
	XFlush(display);
}

void releaseKey(const char *key) {
	if (IS_DEBUG_MODE){
		printf("releasing key: %s\n", key);
	}
	KeyCode keycode = XKeysymToKeycode(display, XStringToKeysym(key));
 	XTestFakeKeyEvent(display, keycode, False, 0);
	XFlush(display);
}

void pressKeyOnce(const char *key) {
	if (IS_DEBUG_MODE){
		printf("pressing key once: %s\n", key);
	}
	KeyCode keycode = XKeysymToKeycode(display, XStringToKeysym(key));
 	XTestFakeKeyEvent(display, keycode, True, 0);
	XTestFakeKeyEvent(display, keycode, False, 0);
	XFlush(display);
}


/**
 *	@brief Callback that handles an event.
 *
 *	@param wm		Pointer to a wiimote_t structure.
 *
 *	This function is called automatically by the wiiuse library when an
 *	event occurs on the specified wiimote.
 */
void handle_event(struct wiimote_t* wm) {
	if (IS_DEBUG_MODE){
		printf("\n\n--- EVENT [id %i] ---\n", wm->unid);
	}

	for (int i = 0; i <MAX_BUTTONS ; ++i) {
		if (IS_JUST_PRESSED(wm, buttonMappings[i].button)) {
			if (buttonMappings[i].continuous) {
				pressKey(getInput(wm->unid, buttonMappings[i].button));
			}
			else {
				pressKeyOnce(getInput(wm->unid, buttonMappings[i].button));
			}
		}
		else if (IS_RELEASED(wm, buttonMappings[i].button) && buttonMappings[i].continuous) {
			releaseKey(getInput(wm->unid, buttonMappings[i].button));
		}
	}
	return;
}

/**
 *	@brief Callback that handles a read event.
 *
 *	@param wm		Pointer to a wiimote_t structure.
 *	@param data		Pointer to the filled data block.
 *	@param len		Length in bytes of the data block.
 *
 *	This function is called automatically by the wiiuse library when
 *	the wiimote has returned the full data requested by a previous
 *	call to wiiuse_read_data().
 *
 *	You can read data on the wiimote, such as Mii data, if
 *	you know the offset address and the length.
 *
 *	The \a data pointer was specified on the call to wiiuse_read_data().
 *	At the time of this function being called, it is not safe to deallocate
 *	this buffer.
 */
void handle_read(struct wiimote_t* wm, byte* data, unsigned short len) {
	int i = 0;

	printf("\n\n--- DATA READ [wiimote id %i] ---\n", wm->unid);
	printf("finished read of size %i\n", len);
	for (; i < len; ++i) {
		if (!(i % 16)) {
			printf("\n");
		}
		printf("%x ", data[i]);
	}
	printf("\n\n");
}


/**
 *	@brief Callback that handles a controller status event.
 *
 *	@param wm				Pointer to a wiimote_t structure.
 *	@param attachment		Is there an attachment? (1 for yes, 0 for no)
 *	@param speaker			Is the speaker enabled? (1 for yes, 0 for no)
 *	@param ir				Is the IR support enabled? (1 for yes, 0 for no)
 *	@param led				What LEDs are lit.
 *	@param battery_level	Battery level, between 0.0 (0%) and 1.0 (100%).
 *
 *	This occurs when either the controller status changed
 *	or the controller status was requested explicitly by
 *	wiiuse_status().
 *
 *	One reason the status can change is if the nunchuk was
 *	inserted or removed from the expansion port.
 */
void handle_ctrl_status(struct wiimote_t* wm) {
	printf("\n\n--- CONTROLLER STATUS [wiimote id %i] ---\n", wm->unid);

	printf("attachment:      %i\n", wm->exp.type);
	printf("speaker:         %i\n", WIIUSE_USING_SPEAKER(wm));
	printf("ir:              %i\n", WIIUSE_USING_IR(wm));
	printf("leds:            %i %i %i %i\n", WIIUSE_IS_LED_SET(wm, 1), WIIUSE_IS_LED_SET(wm, 2), WIIUSE_IS_LED_SET(wm, 3), WIIUSE_IS_LED_SET(wm, 4));
	printf("battery:         %f %%\n", wm->battery_level);
}


/**
 *	@brief Callback that handles a disconnection event.
 *
 *	@param wm				Pointer to a wiimote_t structure.
 *
 *	This can happen if the POWER button is pressed, or
 *	if the connection is interrupted.
 */
void handle_disconnect(wiimote* wm) {
	printf("\n\n--- DISCONNECTED [wiimote id %i] ---\n", wm->unid);
}


void test(struct wiimote_t* wm, byte* data, unsigned short len) {
	printf("test: %i [%x %x %x %x]\n", len, data[0], data[1], data[2], data[3]);
}

short any_wiimote_connected(wiimote** wm, int wiimotes) {
	int i;
	if (!wm) {
		return 0;
	}

	for (i = 0; i < wiimotes; i++) {
		if (wm[i] && WIIMOTE_IS_CONNECTED(wm[i])) {
			return 1;
		}
	}

	return 0;
}


/**
 *	@brief main()
 *
 *	Connect to up to two wiimotes and print any events
 *	that occur on either device.
 */
int main(int argc, char** argv) {

	cJSON * json_object_to_free = load_button_mappings();
	if (json_object_to_free == NULL) {
		printf("Error: Unable to load button mappings.\n");
		return 1;
	}
	if(IS_DEBUG_MODE){
		print_button_mappings();
	}

	display = XOpenDisplay(NULL);

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
		printf("No wiimotes found.\n");
		return 0;
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
		printf("Connected to %i wiimotes (of %i found).\n", connected, found);
	} else {
		printf("Failed to connect to any wiimote.\n");
		return 0;
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

	printf("\nControls:\n");
	printf("\tB toggles rumble.\n");
	printf("\t+ to start Wiimote accelerometer reporting, - to stop\n");
	printf("\tUP to start IR camera (sensor bar mode), DOWN to stop.\n");
	printf("\t1 to start Motion+ reporting, 2 to stop.\n");
	printf("\n\n");

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
	while (any_wiimote_connected(wiimotes, MAX_WIIMOTES)) {
		if (wiiuse_poll(wiimotes, MAX_WIIMOTES)) {
			/*
			 *	This happens if something happened on any wiimote.
			 *	So go through each one and check if anything happened.
			 */
			int i = 0;
			for (; i < MAX_WIIMOTES; ++i) {
				switch (wiimotes[i]->event) {
					case WIIUSE_EVENT:
						/* a generic event occurred */
						handle_event(wiimotes[i]);
						break;

					case WIIUSE_STATUS:
						/* a status event occurred */
						handle_ctrl_status(wiimotes[i]);
						break;

					case WIIUSE_DISCONNECT:
					case WIIUSE_UNEXPECTED_DISCONNECT:
						/* the wiimote disconnected */
						handle_disconnect(wiimotes[i]);
						break;

					case WIIUSE_READ_DATA:
						/*
						 *	Data we requested to read was returned.
						 *	Take a look at wiimotes[i]->read_req
						 *	for the data.
						 */
						break;

					case WIIUSE_NUNCHUK_INSERTED:
						/*
						 *	a nunchuk was inserted
						 *	This is a good place to set any nunchuk specific
						 *	threshold values.  By default they are the same
						 *	as the wiimote.
						 */
						/* wiiuse_set_nunchuk_orient_threshold((struct nunchuk_t*)&wiimotes[i]->exp.nunchuk, 90.0f); */
						/* wiiuse_set_nunchuk_accel_threshold((struct nunchuk_t*)&wiimotes[i]->exp.nunchuk, 100); */
						printf("Nunchuk inserted.\n");
						break;

					case WIIUSE_CLASSIC_CTRL_INSERTED:
						printf("Classic controller inserted.\n");
						break;

					case WIIUSE_WII_BOARD_CTRL_INSERTED:
						printf("Balance board controller inserted.\n");
						break;

					case WIIUSE_GUITAR_HERO_3_CTRL_INSERTED:
						/* some expansion was inserted */
						handle_ctrl_status(wiimotes[i]);
						printf("Guitar Hero 3 controller inserted.\n");
						break;

					case WIIUSE_MOTION_PLUS_ACTIVATED:
						printf("Motion+ was activated\n");
						break;

					case WIIUSE_NUNCHUK_REMOVED:
					case WIIUSE_CLASSIC_CTRL_REMOVED:
					case WIIUSE_GUITAR_HERO_3_CTRL_REMOVED:
					case WIIUSE_WII_BOARD_CTRL_REMOVED:
					case WIIUSE_MOTION_PLUS_REMOVED:
						/* some expansion was removed */
						handle_ctrl_status(wiimotes[i]);
						printf("An expansion was removed.\n");
						break;

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

    cJSON_Delete(json_object_to_free);


	return 0;
}