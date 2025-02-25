require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'


enable :sessions

get('/showlogin') do
  slim(:login)
end

get('/') do
  slim(:register)
end

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

get('/priv_profile') do 

    id = session[:id].to_i
    db = SQLite3::Database.new('db/db.db')
    db.results_as_hash = true 
    result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating, rating.comment FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE user_id = ?", [id])
    slim(:priv_profile, locals:{rating:result})
end 

get('/profile/:id') do 
  user_id = params[:id].to_i 
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating, rating.comment FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE user_id = ?", [user_id])
  slim(:profile, locals:{rating:result})
end

get('/profiles') do
  db = SQLite3::Database.new('db/db.db')
  db.results_as_hash = true 
  users = db.execute("SELECT * FROM users")
  slim(:profiles, locals:{users:users})
end

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

post('/rating/new') do
  user_id = session[:id]
  rating = params[:rating].to_i
  title = params[:title]
  author = params[:author]
  series = params[:series]
  comment = params[:comment]
  db = SQLite3::Database.new('db/db.db')
  db.execute('INSERT INTO rating (user_id,rating,comment) VALUES (?,?,?)', [session[:id], rating,comment])
  db.execute('INSERT INTO media (author, title, series) VALUES (?,?,?)', [author,title,series])
  redirect('/priv_profile')
end

