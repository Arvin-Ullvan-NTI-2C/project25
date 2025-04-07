require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

# Restricts access to specific routes unless logged in
#
before do 
  restricted_paths = ['/priv_profile']

  if (session[:id] == nil) && restricted_paths.include?(request.path_info)
    redirect '/error'
  end
end

# Displays an error page
#
get('/error') do
  slim(:error)
end

# Displays the login form
#
get('/showlogin') do
  slim(:login)
end

# Displays the registration form
#
get('/') do
  slim(:register)
end

# Logs out the user and clears session
#
get('/logout') do
  session[:id] = nil 
  redirect("/")
end

# Attempts login and updates the session
#
# @param [String] username, The username
# @param [String] password, The password
#
post('/login') do
  username = params[:username]
  password = params[:password] 
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  result = db.execute("SELECT * FROM users WHERE username = ?", [username]).first
  pwdigest = result["pwdigest"]
  id = result["id"]
  session[:username] = username

  if BCrypt::Password.new(pwdigest) == password 
    session[:id] = id
    redirect('/priv_profile')
  else
    "FEL LÖSEN!"
  end
end

# Displays the private profile for the logged-in user
#
# @see /priv_profile
get('/priv_profile') do 
  id = session[:id].to_i
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating, rating.comment, rating.rating_id FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE user_id = ?", [id])
  slim(:priv_profile, locals:{rating:result})
end 

# Displays a public profile for a user by ID
#
# @param [Integer] :id, the user ID
get('/profile/:id') do 
  user_id = params[:id].to_i 
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating, rating.comment FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE user_id = ?", [user_id])
  slim(:profile, locals:{rating:result})
end

# Displays a list of all user profiles
#
get('/profiles') do
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  users = db.execute("SELECT * FROM users")
  slim(:profiles, locals:{users:users})
end

# Registers a new user and logs them in
#
# @param [String] username, The username
# @param [String] password, The password
# @param [String] password_confirm, The password confirmation
post('/users/new') do 
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  session[:username] = username

  if (password == password_confirm)
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/db.db')
    db.results_as_hash = true 
    db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',[username,password_digest])
    result = db.execute("SELECT * FROM users WHERE username = ?", [username]).first
    id = result["id"]
    session[:id] = id
    redirect('/priv_profile')
  else
    "Lösenorden matchade inte"
  end
end

# Creates a new rating and inserts media if not existing
#
# @param [Integer] rating, The rating score
# @param [String] title, The media title
# @param [String] author, The media author
# @param [String] series, The media series
# @param [String] comment, The user's comment
post('/rating/new') do
  user_id = session[:id]
  rating = params[:rating].to_i
  title = params[:title]
  author = params[:author]
  series = params[:series]
  comment = params[:comment]
  rating_id = params[:rating_id].to_i  

  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 

  # Check if the media already exists
  media = db.execute("SELECT id FROM media WHERE title = ? AND author = ? AND series = ?", [title, author, series]).first

  if media
    media_id = media["id"]
  else
    # Insert media only if it doesn't exist
    db.execute('INSERT INTO media (author, title, series) VALUES (?,?,?)', [author, title, series])
    media_id = db.last_insert_row_id
  end

  # Insert rating using the correct media_id
  db.execute('INSERT INTO rating (user_id, media_id, rating, comment) VALUES (?,?,?,?)', [user_id, media_id, rating, comment])
  
  redirect('/priv_profile')
end

# Deletes a rating based on rating ID
#
# @param [Integer] :rating_id, The ID of the rating to delete
post('/rating/:rating_id/delete') do
  rating_id = params[:rating_id].to_i  
  db = SQLite3::Database.new('db/db.db')
  db.execute("DELETE FROM rating WHERE rating_id = ?", [rating_id])
  redirect('/priv_profile')
end

# Displays the form to edit a specific rating
#
# @param [Integer] :rating_id, The ID of the rating
get('/rating/:rating_id/edit') do 
  id = params[:rating_id].to_i
  db = SQLite3::Database.new("db/db.db")
  db.results_as_hash = true 
  result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating, rating.comment, rating.rating_id FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE rating_id = ?", [id]).first  
  slim(:edit, locals:{rating:result})
end

# Updates a rating and associated media details
#
# @param [Integer] :rating_id, The ID of the rating
# @param [String] title, The updated title
# @param [String] author, The updated author
# @param [String] series, The updated series
# @param [Integer] rating, The updated rating
# @param [String] comment, The updated comment
post('/rating/:rating_id/update') do
  id = params[:rating_id].to_i
  title = params[:title]
  series = params[:series] 
  author = params[:author]
  rating = params[:rating]
  comment = params[:comment]
  db = SQLite3::Database.new("db/db.db")

  db.execute("UPDATE media SET title=?, author=?, series=? WHERE id = (SELECT media_id FROM rating WHERE rating_id = ?)", [title, author, series, id])
  db.execute("UPDATE rating SET rating=?, comment=? WHERE rating_id = ?", [rating, comment, id])

  redirect('/priv_profile')
end
