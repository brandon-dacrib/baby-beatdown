-- music.lua: one theme per stage. Songs are set up silent (at = false) and started when a stage is built.
SONG_NAMES = { "bayou", "backyard", "rooftop", "farm", "pond", "cave", "garden", "leaf" }
SONGS = {}
for i = 1, 8 do SONGS[i] = score{ song = SONG_NAMES[i], loop = true, at = false } end
MUSIC_NOW = 0

function play_music(i)
  if MUSIC_NOW == i then return end
  if TUNE then TUNE.stop() end
  for j = 1, 8 do if j ~= i then SONGS[j].stop() end end
  SONGS[i].play()
  MUSIC_NOW = i
end

local base_build_stage = build_stage
function build_stage(ci)
  base_build_stage(ci)
  play_music(ci)
end
