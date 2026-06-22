-- mod-environmental-effects: enable weather in the added outdoor zones so their
-- weather-triggered debuffs can fire (these zones are absent from base game_weather).
-- Rain: Swamp of Sorrows(8), Westfall(40), Silverpine(130), Ashenvale(331), Terokkar(3519).
-- Snow: Howling Fjord(495).
REPLACE INTO `game_weather`
  (`zone`,`spring_rain_chance`,`spring_snow_chance`,`spring_storm_chance`,
   `summer_rain_chance`,`summer_snow_chance`,`summer_storm_chance`,
   `fall_rain_chance`,`fall_snow_chance`,`fall_storm_chance`,
   `winter_rain_chance`,`winter_snow_chance`,`winter_storm_chance`,`ScriptName`)
VALUES
  (8,   25,0,0, 25,0,0, 25,0,0, 20,0,0, ''),
  (40,  25,0,0, 20,0,0, 25,0,0, 25,0,0, ''),
  (130, 25,0,0, 20,0,0, 25,0,0, 25,0,0, ''),
  (331, 25,0,0, 20,0,0, 25,0,0, 25,0,0, ''),
  (3519,20,0,0, 20,0,0, 20,0,0, 20,0,0, ''),
  (495, 0,25,0, 0,20,0, 0,25,0, 0,30,0, '');
