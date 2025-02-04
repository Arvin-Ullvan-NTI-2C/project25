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

  if BCrypt::Password.new(pwdigest) == password 
    session[:id] = id
    redirect('/profile')
  else
    "FEL LÖSEN!"
  end

end

get('/profile') do 

    id = session[:id].to_i
    db = SQLite3::Database.new('db/db.db')
    db.results_as_hash = true 
    result = db.execute("SELECT media.title, media.author, media.series, users.username, rating.rating FROM ((rating INNER JOIN users ON rating.user_id = users.id) INNER JOIN media ON rating.media_id = media.id) WHERE user_id = ?", [id])
    slim(:profile, locals:{rating:result})
end 

post('/users/new') do 
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
  
    if (password == password_confirm)
      password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new('db/db.db')
      db.execute('INSERT INTO users (username,pwdigest) VALUES (?,?)',[username,password_digest])
      redirect('/profile')
    else
      "Lösenorden matchade inte"
    end
  end