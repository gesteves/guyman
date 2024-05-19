namespace :playlists do
  desc "Delete playlists older than N days"
  task :delete_old, [:days] => :environment do |t, args|
    if args[:days].nil?
      puts "Please provide the number of days. Usage: rake playlists:delete_old[30]"
      exit 1
    end

    days = args[:days].to_i
    cutoff_date = days.days.ago

    playlists_to_delete = Playlist.where('created_at < ?', cutoff_date)

    if playlists_to_delete.any?
      puts "Are you sure you want to delete #{playlists_to_delete.size} playlists older than #{days} days? (yes/no)"
      confirm = $stdin.gets.chomp.downcase

      if confirm == 'yes'
        playlists_to_delete.each do |playlist|
          playlist.destroy
        end
        puts "#{playlists_to_delete.size} playlists older than #{days} days have been deleted."
      else
        puts "Operation cancelled."
      end
    else
      puts "No playlists found older than #{days} days."
    end
  end

  desc "Delete ALL playlists"
  task :delete_all => :environment do
    playlists_count = Playlist.count

    if playlists_count > 0
      puts "Are you sure you want to delete ALL #{playlists_count} playlists? (yes/no)"
      confirm = $stdin.gets.chomp.downcase

      if confirm == 'yes'
        Playlist.destroy_all
        puts "All #{playlists_count} playlists have been deleted."
      else
        puts "Operation cancelled."
      end
    else
      puts "No playlists found to delete."
    end
  end
end
