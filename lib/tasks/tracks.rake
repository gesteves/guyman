namespace :tracks do
  desc "Populate position attribute on existing tracks"
  task populate_positions: :environment do
    say "Starting to populate positions for existing tracks..."
    
    Playlist.find_each do |playlist|
      playlist.tracks.order(:created_at).each_with_index do |track, index|
        track.update_column(:position, index + 1)
      end
    end
    
    say "Finished populating positions for existing tracks."
  end
end
