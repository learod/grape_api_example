class Api
  resource :albums do
    before do
      authenticate!
    end

    get do
      cached_response(Entities::Album) { Models::Album.all }
    end

    post do
      result = CreateAlbumValidation.new(params).validate
      if result.success? && album = Models::Album.create(result.output)
        call_cache(Entities::Album) { album }
      else
        error!(result.messages, 400)
      end
    end

    get ':id' do
      album = cached_response(Entities::Album) { Models::Album[params[:id]] }
      return error!(:not_found, 404) unless album

      album
    end

    put ':id' do
      album = Models::Album[params[:id]]
      return error!(:not_found, 404) unless album

      result = EditAlbumValidation.new(params).validate
      if result.success? && album.update(result.output)
        call_cache(Entities::Album) { album }
      else
        error!(result.messages, 400)
      end
    end

    delete ':id' do
      album = Models::Album[params[:id]]
      return error!(:not_found, 404) unless album
      album.destroy
      call_cache(Entities::Album) { album }
    end

    put ':id/songs' do
      album = Models::Album[params[:id]]
      song = Models::Song[params[:song_id]]
      return error!(:not_found, 404) unless album && song

      song_to_add = Models::AlbumSong.new(album_id: album.id, song_id: song.id)
      begin
        if song_to_add.save
          Entities::Album.represent(album)
        else
          error!('Fail to add song to the current album.', 400)
        end
      rescue Sequel::UniqueConstraintViolation
        error!('This song was already added to this album.', 400)
      end
    end

    delete ':id/songs' do
      album = Models::Album[params[:id]]
      song = Models::Song[params[:song_id]]
      return error!(:not_found, 404) unless album && song

      Models::AlbumSong.where(album_id: album.id, song_id: song.id).destroy
      Entities::Album.represent(album)
    end
  end
end
