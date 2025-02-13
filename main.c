#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>
#include <ESP8266mDNS.h> // For mDNS

ESP8266WebServer server(80); // Create a web server object
const int relayPin = 2;       // GPIO2 controls the relay

// Relay control endpoints
void handleRelayOn() {
  digitalWrite(relayPin, LOW); // Activate relay
  server.send(200, "text/plain", "Relay is ON");
}

void handleRelayOff() {
  digitalWrite(relayPin, HIGH); // Deactivate relay
  server.send(200, "text/plain", "Relay is OFF");
}

// Status endpoint
void handleStatus() {
  String state = digitalRead(relayPin) == LOW ? "ON" : "OFF";
  server.send(200, "application/json", "{\"state\": \"" + state + "\"}");
}

void setup() {
  Serial.begin(115200);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, HIGH); // Ensure relay is off at startup

  // WiFiManager setup
  WiFiManager wifiManager;
  if (!wifiManager.autoConnect("ESP-Relay")) {
    Serial.println("Failed to connect to Wi-Fi. Restarting...");
    ESP.restart();
  }

  Serial.println("Connected to Wi-Fi!");

  // Start mDNS
  if (MDNS.begin("esp-relay")) {
    Serial.println("mDNS responder started");
    MDNS.addService("http", "tcp", 80); // Advertise HTTP service
  } else {
    Serial.println("Error setting up mDNS responder!");
  }

  // Define HTTP endpoints
  server.on("/", []() {
    server.send(200, "text/plain", "ESP Relay is running! Use /on, /off, or /status.");
  });

  server.on("/on", handleRelayOn);
  server.on("/off", handleRelayOff);
  server.on("/status", handleStatus);

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient(); // Handle incoming HTTP requests
  MDNS.update();         // Keep mDNS running
}
