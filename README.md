iSXMDataProtection
============

iSXMDataProtection is a module that performs static analysis on the application’s executable binary in order to check if the application has the potential for accessing sensitive information and transmitting them over a network connection.

The module provides the following metrics:

* dp_calendar set to 1 whether the app can access calendar/reminders, 0 otherwise;
* dp_micro set to 1 whether the app can record audio from the microphone, 0 otherwise;
* dp_media set to 1 whether the app can access the camera/library, 0 otherwise; 
* dp_contacts set to 1 whether the app can access the contacts list, 0 otherwise; 
* dp_location set to 1 whether the app can get the device’s location, 0 otherwise;
* dp_social set to 1 whether the app can access Twitter’s or Facebook’s data, 0 otherwise;
* dp_network set to 1 whether the app can make network connections, 0 otherwise.
