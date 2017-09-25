Namespace insectoids

#Import "assets/"
#Import "<std>"
#Import "<mojo>"

Using std..
Using mojo..

Const VIRTUAL_RESOLUTION := New Vec2i(512, 480)

Global Insectoids:InsectoidsApp

Class Sprite
	Field position:Vec2f
	Field image:Image
	Field images:Image[]
	Field frame:Int
	Field maxFrame:Int
	Field frameDelay:Int
	Field maxFrameDelay:Int
	Field rotation:Float = Pi / 2
	Field scale:Vec2f = New Vec2f(1, 1)
	Field speed:Vec2f = New Vec2f(1, 1)
	Field state:Int
	Field color:Color = Color.White
	Field dead:Bool
	Field wrapImageX:Bool = True
	Field wrapImageY:Bool = True
	
	Method New()
	End
	
	Method New(image:Image, position:Vec2i)
		Self.image = image
		Self.position = position
	End
	
	Method Render(canvas:Canvas) Virtual
		canvas.Color = color
		image.Scale = scale
		Local r := rotation - Pi / 2
		canvas.DrawImage(image, position, r)
		
		If wrapImageX
			If position.X - image.Radius < 0 canvas.DrawImage(image, position.X + VIRTUAL_RESOLUTION.X, position.Y, r)
			If position.X + image.Radius > VIRTUAL_RESOLUTION.X canvas.DrawImage(image, position.X - VIRTUAL_RESOLUTION.X, position.Y, r)
		End
		
		If wrapImageY
			If position.Y - image.Radius < 0 canvas.DrawImage(image, position.X, position.Y + VIRTUAL_RESOLUTION.Y, r)
			If position.Y + image.Radius > VIRTUAL_RESOLUTION.Y canvas.DrawImage(image, position.X, position.Y - VIRTUAL_RESOLUTION.Y, r)
		End
		
		canvas.Color = Color.White
	End
	
	Method RenderFrame(canvas:Canvas, frame:Int = 0) Virtual
		canvas.Color = color
		images[frame].Scale = scale
		canvas.DrawImage(images[frame], position)
		canvas.Color = Color.White
	End

	Method Update() Virtual
	End
End

Class Player Extends Sprite
	Field lives:Int
	Field score:Int
	Field bang:Int
	Field startPosition:Vec2i
	Field fireDelay:int
	Const ALIVE:Int = 1
	Const DEAD:Int = 2

	Const MAX_BULLETS:Int = 3
	
	Method New(image:Image, position:Vec2i)
		Self.image = image
		Self.startPosition = position
		Self.lives = 3
		Self.speed.X = 6
		Self.scale = New Vec2f(1, 1)
		Reset()
	End
	
	Method Reset()
		Self.state = ALIVE
		Self.dead = False
		Self.position = startPosition
		Self.fireDelay = 15
	End
	
	Method Render(canvas:Canvas) Override
		RenderGUI(canvas)
		If state = ALIVE
			Super.Render(canvas)
		Else
			bang += 8
			Local r:Float = bang
			For Local i:Float = 255 To 1 Step -15
				canvas.Color = New Color(i / 255, i / 255, i / 255)
				For Local angle:Int = 0 To 359 Step 6
					Local x:Int = position.X + Cosd(angle) * r
					Local y:Int = position.Y + Sind(angle) * r
					canvas.DrawRect(x, y, 3, 3)
				Next
				r -= 6
				If r <= 0 Then Exit
			Next
		End
	End
	
	Method RenderGUI(canvas:Canvas)
		canvas.Color = Color.White
		canvas.DrawText(Self.score, VIRTUAL_RESOLUTION.X / 2, 8, .5)
		image.Scale = New Vec2f(.7, .7)
		For Local i:Int = 1 To Self.lives
			canvas.DrawImage(Self.image, i * image.Width + 4, 14)
		End
		image.Scale = New Vec2f(1, 1)
	End
	
	Method Update() Override
		If state <> ALIVE Return
		Controls()
	End
	
	Method Controls()
		Local leftKey := Keyboard.KeyDown(Key.Left) Or Keyboard.KeyDown(Key.A)
		Local rightKey := Keyboard.KeyDown(Key.Right) Or Keyboard.KeyDown(Key.D)
		Local fireKey := Keyboard.KeyDown(Key.Space)
		

		If leftKey
			If position.X > image.Width
				position.X -= speed.X
			End
		Else If rightKey
			If position.X < VIRTUAL_RESOLUTION.X - image.Width
				position.X += speed.X
			End
		End
		
		If Insectoids.GameState <> Insectoids.STATE_GAME Then Return
		
		If fireDelay > 0
			fireDelay -=1
		End
		
		If fireKey And Bullet.list.Count() < MAX_BULLETS And fireDelay = 0
			New Bullet(InsectoidsApp.BulletImage, New Vec2f(position.X, position.Y - 16))
			Insectoids.shootSound.Play()
			fireDelay = 10
		End
		
		' collisions with aliens
		For Local a:Alien = Eachin Alien.list
			If CircleOverlap(position, image.Height / 2, a.position, a.image.Height / 2)
				dead = True
				Exit
			Endif
		Next
		
		' collisions with bombs
		For Local b:Bomb = Eachin Bomb.list
			If CircleOverlap(position, image.Height / 2, b.position, b.image.Height / 2)
				dead = True
				Exit
			EndIf
		Next
		If dead
			Insectoids.boomSound.Play()
			
			For Local k:Int = -105 To 0 Step 15
				Local v := New Vec2i(position.X + Rnd(-20, 20), position.Y + Rnd(-20, 20))
				New Explosion(Insectoids.ExplosionImage, v)
			Next
			bang = 1
			lives -= 1
			state = DEAD
			Insectoids.GameState = Insectoids.STATE_DEAD
		End
	End
End

Class Bullet Extends Sprite
	Global list:List<Bullet> = New List<Bullet>
	
	Method New(image:Image, position:Vec2i)
		Self.image = image
		Self.position = position
		Self.scale = New Vec2f(.5, 1)
		Self.speed.Y = 8
		Self.wrapImageX = False
		Self.wrapImageY = False
		list.AddLast(self)
	End
	
	Function RenderAll:Void(canvas:Canvas)
		If Not list Return
		For Local a:Bullet = Eachin list
			a.Render(canvas)
		Next		
	End
	
	Function UpdateAll:Void()
		If Not list Return
		
		Local it := list.All()
		While Not it.AtEnd
			Local b:Bullet = it.Current
			b.Update()
			If b.position.Y <= 0 Or b.dead
				it.Erase()
			Else
				it.Bump()
			End
		End
	End
	
	Method Update() Override
		position.Y -= speed.Y
	End
End

Class Explosion Extends Sprite
	Global list:List<Explosion> = New List<Explosion>
	Field finished:Bool = False
	
	Method New(image:Image[], position:Vec2i)
		Self.images = image
		Self.position = position
		Self.maxFrame = 5
		Self.scale = New Vec2f(.6, .6)
		Self.maxFrameDelay = 3
		
		list.AddLast(self)
	End
	
	Function RenderAll:Void(canvas:Canvas)
		If Not list Return
		For Local e:Explosion = Eachin list
			e.RenderFrame(canvas, e.frame)
		Next
	End
	
	Function UpdateAll:Void()
		If Not list Return
		
		Local it := list.All()
		While Not it.AtEnd
			Local e:Explosion = it.Current
			e.Update()
			If e.finished
				it.Erase()
			Else
				it.Bump()
			End
		End
	End
	
	Method Update() Override
		frameDelay += 1
		If frameDelay > maxFrameDelay
			frame += 1
			If frame > maxFrame
				frame = maxFrame
				finished = True
			End
			frameDelay = 0
		End
	End
End

Class Bomb Extends Sprite
	Global list:List<Bomb> = New List<Bomb>
		
	Method New(image:Image, position:Vec2i)
		Self.image = image
		Self.position = position
		Self.scale = New Vec2f(.6, .6)
		Self.dead = False
		Self.wrapImageX = True
		Self.wrapImageY = False
		list.AddLast(self)
	End
	
	Function RenderAll:Void(canvas:Canvas)
		If Not list Return
		For Local b:Bomb = Eachin list
			b.Render(canvas)
		Next		
	End
	
	Function UpdateAll:Void()
		If Not list Return
		
		Local it := list.All()
		While Not it.AtEnd
			Local b:Bomb = it.Current
			b.Update()
			If b.dead Or b.position.Y > VIRTUAL_RESOLUTION.Y
				If b.dead Then New Explosion(Insectoids.ExplosionImage, b.position)
				it.Erase()
			Else
				it.Bump()
			End
		End

	End
	
	Method Update() Override
		position.X += speed.X
		position.Y += speed.Y
	End
End

Class Alien Extends Sprite
	Global list:List<Alien> = New List<Alien>
	Global noOfFlying:Int
	Global flyTimer:Int
	Global formationPosition:Vec2f
	Global formationSpeedDelta:Vec2f
	Global formationDirection:Float
	Global reverseDirection:Bool
	Global formationPhase:Float
	Global formationSpeed:Float
	Global formationSize:Vec2f
	
		
	Field bombCount:Int
	Field firstPosition:Vec2f
	Field destY:Float
	Field destRot:Float, rotStep:Float
	
	Const FORMATION_FLYING:Int = 1
	Const FLYING_STATE_1:Int = 2
	Const FLYING_STATE_2:Int = 3
	
	Method New(image:Image, position:Vec2i)
		Self.image = image
		Self.position = position
		Self.scale = New Vec2f(.6, .6)
		Self.dead = False
		Self.wrapImageY = False
		list.AddLast(self)
	End
	
	Function RenderAll:Void(canvas:Canvas)
		If Not list Return
		For Local a:Alien = Eachin list
			a.Render(canvas)
		Next		
	End

	Function UpdateAll:Void()
		If Not list Return
		
		reverseDirection = False
		Local it := list.All()
		While Not it.AtEnd
			Local a:Alien = it.Current
			a.Update()
			For Local b:Bullet = Eachin Bullet.list
				If a <> Null And Not a.dead And Not b.dead
					If CircleOverlap(a.position, a.image.Height / 2, b.position, b.image.Height / 2)
						Insectoids.kazapSound.Play()
						a.dead = True
						b.dead = True
						Local points:Int
						If a.state = FORMATION_FLYING
							points = 25
						Elseif a.state = FLYING_STATE_1
							points = 50
						Else
							points = 100
						End
						If Insectoids.player
							Insectoids.player.score += points
						End
						If a.state <> FORMATION_FLYING Then noOfFlying -= 1
					End
				End
			End	
			If a.dead
				New Explosion(Insectoids.ExplosionImage, a.position)
				it.Erase()
			Else
				it.Bump()
			End
		End
		If reverseDirection formationDirection = -formationDirection
	End
	
	Method Update() Override
		Select state
			Case FORMATION_FLYING
				If Self.rotation <> Pi / 2
					Local rotationSpeed:Float = 0.10472 ' 6 degrees
					If Self.rotation > Pi  Self.rotation += rotationSpeed Else Self.rotation -= rotationSpeed
					If Self.rotation < Pi / 2 Or Self.rotation > Pi / 2 Self.rotation = Pi / 2
				End
				Local dx := formationPosition.X + firstPosition.X * formationSpeedDelta.X - position.X
				Local dy := formationPosition.Y + firstPosition.Y * formationSpeedDelta.Y - position.Y
			'	Print dx +","+ dy
				Local delta:Vec2f = New Vec2f(dx, dy)
				
				If delta.X < -speed.X Then delta.X = -speed.X Else If delta.X > speed.X Then delta.X = speed.X
				If delta.Y < -speed.Y Then delta.Y = -speed.Y Else If delta.Y > speed.Y Then delta.Y = speed.Y
				
				position += delta

				If formationDirection < 0 And position.X < 16 Then reverseDirection = True
				If formationDirection > 0 And position.X > VIRTUAL_RESOLUTION.X - 16 Then reverseDirection = True
			Case FLYING_STATE_1
				Self.rotation += rotStep
				rotation = WrapRotation(rotation)
				If Self.rotation < Pi / 2 Or Self.rotation > (TwoPi - Pi / 2)
					destRot = Rnd(4, 5) ' angle downwards on the screen
					destY += Rnd(100, 300)
					state = FLYING_STATE_2
				End
				position += New Vec2f( Cos( rotation )  * speed.X ,-Sin( rotation ) * speed.Y )
				DropBomb()
				
				position.X = (position.X + VIRTUAL_RESOLUTION.X) Mod VIRTUAL_RESOLUTION.X

			Case FLYING_STATE_2
				Local dr := Self.rotation - destRot
				If Abs(dr) > Abs(rotStep)
					rotation += rotStep
					rotation = WrapRotation(rotation)
				End
				
				position += New Vec2f( Cos( rotation ) * speed.X ,-Sin( rotation ) * speed.Y )
				position.X = (position.X + VIRTUAL_RESOLUTION.X) Mod VIRTUAL_RESOLUTION.X

				If position.Y > VIRTUAL_RESOLUTION.Y
					position.X = Rnd(0, VIRTUAL_RESOLUTION.X / 2) + VIRTUAL_RESOLUTION.X / 4
					position.Y = 0
					noOfFlying -=1
					state = FORMATION_FLYING
				Else If position.Y > destY
					rotStep = -rotStep
					state = FLYING_STATE_1 
				End
				DropBomb()
		End
	End
	
	Method WrapRotation:Float(rotation:Float)
		Local r:Float = rotation
		If r < 0 r += TwoPi Else If r >= TwoPi r -= TwoPi
		Return r
	End
	
	Method DropBomb()
		If bombCount = 0 Then bombCount = Rnd(50, 100)
		bombCount -= 1
		If bombCount > 0 Return
		Local b:Bomb = New Bomb(Insectoids.BombImage, position)
		If position.X < Insectoids.player.position.X Then b.speed.X = 1 Else b.speed.X = -1
		b.speed.Y = 6
	End
	
	Function UpdateFormation()
		formationPhase = (formationPhase + formationSpeed) Mod 360
		
		Local t:Float = Sind(formationPhase) * .5 + .5

		formationSpeedDelta.X  = t * formationSize.X + 2
		formationSpeedDelta.Y  = t * formationSize.Y + 2
		If Insectoids.STATE_GAME <> Insectoids.STATE_TITLE
			formationPosition.X += formationDirection
		End
	End
	
	Function UpdateFlyTimer()
		If list.Count() > 3
			If flyTimer = 0 Then flyTimer = 400
			flyTimer -= 1
			If flyTimer > 120 Then Return
			If flyTimer Mod 30 <> 0 Then Return
		End

		Local noAliensNotFlying:Int = Rnd(list.Count() - noOfFlying)
		For Local a:Alien = Eachin Alien.list
			If a.state = FORMATION_FLYING
				If noAliensNotFlying = 0
					a.destY = a.position.Y
					Local rotationSpeed:Float = 0.0523599 ' 3 degrees
					a.rotStep = rotationSpeed
					If Rnd(1) < .5 Then a.rotStep = -rotationSpeed
					noOfFlying += 1
					a.state = FLYING_STATE_1
					Return
				End
				noAliensNotFlying -= 1
			End
		Next
	End
	
End

Class InsectoidsApp Extends Window
	Const FPS:Int = 60
	
	Const STATE_TITLE:Int= 1
	Const STATE_START_GAME:Int = 2
	Const STATE_GAME:Int = 3
	Const STATE_DEAD:Int = 4
	Const STATE_GAME_OVER:Int = 5
	Const STATE_GAME_WIN:Int = 6
	
	Global GameState:Int = STATE_TITLE
	Global BulletImage:Image
	Global ExplosionImage:Image[]
	Global BombImage:Image
	
	Field gameTimer:Int
	Field timer:Timer
	Field player:Player
	Field playerImage:Image
	Field alienImage:Image
	Field insectoidsLogo:Image
	Field mx2Logo:Image
	Field starBackground:Image
	
	Global boomSound:Sound
	Global coolSound:Sound
	Global kazapSound:Sound
	Global shootSound:Sound
	
	Field starsScroll:Int
	Field font:Font
	Field level:Int 
	Field levelName:String
	Field maxLevel:Int
	
	Method New()
		Super.New("Insectoids", 1027, 768, WindowFlags.Resizable)
		Layout = "letterbox"
		timer = New Timer(FPS, OnUpdate)
		ClearColor = Color.Black
		SeedRnd(Millisecs())
		LoadAssets()
		maxLevel = 6
		Mouse.PointerVisible = False
	End
	
	Method LoadAssets()
		' graphics
		ExplosionImage = LoadFrames("graphics/kaboom.png", 6, 60, 48)
		BombImage      = GetImage("graphics/bbomb.png")
		BulletImage    = GetImage("graphics/bullet.png")
		insectoidsLogo = GetImage("graphics/insectoids_logo.png")
		starBackground = GetImage("graphics/stars.png")
		alienImage     = GetImage("graphics/alien.png")
		playerImage    = GetImage("graphics/player.png")
		mx2Logo        = GetImage("graphics/monkey2logo.png")
		
		' fonts
		font = GetFont("fonts/arial.ttf", 24)
		
		' sounds
		boomSound  = GetSound( "sounds/boom.ogg" )
		coolSound  = GetSound( "sounds/cool.ogg" )
		kazapSound = GetSound( "sounds/kazap.ogg" )
		shootSound = GetSound( "sounds/shoot.ogg" )
	End
	
	Method BeginGame()
		player = New Player(playerImage, New Vec2f(VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y - 20))
		level = 1		
		BeginLevel()
		Alien.noOfFlying = 0
		gameTimer = 0
	End
	
	Method CreateAliens(x:Float, y:Float, alienCount:Int)
		For Local i:Int = 1 To alienCount
			Local a:Alien = New Alien(alienImage, Alien.formationPosition)
			a.rotation = Pi / 2
			a.state = Alien.FORMATION_FLYING
			a.firstPosition = New Vec2f(x * 16, y * 12)
			a.speed.X = 6 + level - 1
			a.speed.Y = 6 + level - 1
			If a.speed.X > 6 Then a.speed.X = 6
			If a.speed.Y > 6 Then a.speed.Y = 6
			x += 1
		Next
	End	

	Method LoadLevel()
		Local error:Bool = False
		Local debug:Bool = False
		If level > maxLevel
			GameState = STATE_GAME_WIN
			Return
		End
		Local jsonData := LoadString( "asset::levels/level" + level + ".json" )
		Local json:JsonObject = JsonObject.Parse(jsonData)
		If json
			Local jsonLevel:JsonObject = json.GetObject("level")
			If jsonLevel
				levelName = jsonLevel.GetString("name")
				Alien.formationSpeed = jsonLevel.GetNumber("formation_speed")
				Alien.formationSize = New Vec2f(jsonLevel.GetNumber("formation_x_size"), jsonLevel.GetNumber("formation_y_size"))
				Alien.formationPosition = New Vec2f(VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 4)
				If debug
					Print "levelName = " + levelName
					Print "Alien.formationSpeed = " + Alien.formationSpeed
					Print "Alien.formationSize  = " + Alien.formationSize
				End
				
				Local aliens:JsonObject = jsonLevel.GetObject("alien_rows")
				If aliens
					Local alienArray:JsonArray = aliens.GetArray("alien_row")
					If alienArray
						For Local i := 0 Until alienArray.Length
							Local alienObject:JsonObject = alienArray.GetObject(i)
							If alienObject
								Local x:Float = alienObject.GetNumber("x")
								Local y:Float = alienObject.GetNumber("y")
								Local amount:Int = alienObject.GetNumber("amount")
								If debug Then Print x + ", " + y + ", amount = " + amount
								
								CreateAliens(x, y, amount)
							Else
								Print "Invalid alienObject"
								error = True
							End
						Next
					Else
						Print "Invalid alienArray"
						error = True
					End	
				Else
					Print "Invalid aliens"
					error = True
				End
			Else
				Print "Invalid level"	
				error = True
			End
		Else
			Print "Invalid JSON"
			error = True
		End
		If error
			App.Terminate()
		End
	End

	Method BeginLevel()
		coolSound.Play()
		GameState = STATE_START_GAME
		gameTimer = 0
		LoadLevel()
		Bullet.list.Clear()
		Bomb.list.Clear()
		Alien.formationPosition = New Vec2f(VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 4)
		Alien.formationPhase = 0
		Alien.formationDirection = 1
	End
	
	Method OnKeyEvent( event:KeyEvent ) Override
		Select event.Type
			Case EventType.KeyDown
				Select event.Key
					Case Key.Enter
						If event.Modifiers & Modifier.Alt
							If Fullscreen EndFullscreen() Else BeginFullscreen()
						End
				End
		End
	End
	
	Method OnWindowEvent(event:WindowEvent) Override
		Select event.Type
			Case EventType.WindowGainedFocus
				If timer timer.Suspended = False
			Case EventType.WindowLostFocus
				If timer timer.Suspended = True
			Default
				Super.OnWindowEvent( event )
		End
	End
	
	Method OnUpdate()
		RequestRender()
				
		If Keyboard.KeyDown(Key.Escape)
			If GameState = STATE_TITLE
				App.Terminate()
			Else
				GameState = STATE_GAME_OVER
			End		
		End
		
		Select GameState
			Case STATE_TITLE
				gameTimer += 1
				If Keyboard.KeyDown(Key.Space)
					BeginGame()
				End
			Case STATE_START_GAME
				gameTimer +=1 
				If gameTimer = 150 Then
					GameState = STATE_GAME
					gameTimer = 0
				End
				Alien.UpdateFormation()
			Case STATE_GAME
				Alien.UpdateFlyTimer()
				Alien.UpdateFormation()
				If Alien.list.Count() = 0 Then 
					level += 1
					BeginLevel()
				End
			Case STATE_DEAD
				Alien.UpdateFormation()
				If Alien.noOfFlying = 0 And  Explosion.list.Count() = 0
					If player.lives > 0
						player.Reset()
						GameState = STATE_START_GAME
					Else
						gameTimer = 0
						GameState = STATE_GAME_OVER
					End
				End
			Case STATE_GAME_OVER
				Alien.UpdateFlyTimer()
				Alien.UpdateFormation()
				gameTimer += 1
				If gameTimer =150 Then
					EndGame()
				End
			Case STATE_GAME_WIN
				gameTimer += 1
				If gameTimer =150 Then
					EndGame()
				End
		End	
		
		starsScroll = (starsScroll - 1) Mod starBackground.Height
		If player Then player.Update()
		Alien.UpdateAll()
		Bomb.UpdateAll()
		Bullet.UpdateAll()
		Explosion.UpdateAll()
		
	End
	
	Method EndGame()
		GameState = STATE_TITLE
		Alien.list.Clear()
		Bullet.list.Clear()
		Explosion.list.Clear()
		player = Null
		gameTimer = 0
	End
	
	Method OnRender(canvas:Canvas) Override

		canvas.Font = font
		canvas.TextureFilteringEnabled = False
		
		RenderGame(canvas)
		
		Select GameState
			Case STATE_TITLE
				RenderTitleScreen(canvas)
			Case STATE_START_GAME
				canvas.Color = Rainbow(gameTimer * 5)
				canvas.DrawText(levelName, VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 2, .5, .5)
			Case STATE_GAME_OVER
				RenderGameOver(canvas)
			Case STATE_GAME_WIN
				RenderGameWin(canvas)
		End	
		canvas.Color = Color.White
	End
	
	Method Rainbow:Color(time:Int)
		Local r:Int = time Mod 768
		If r > 255 Then r = 511 - r
		Local g:Int = (time + 256) Mod 768
		If g > 255 Then g = 511 - g
		Local b:Int = (time + 512) Mod 768
		If b > 255 Then b = 511 - b
		If r < 0 Then r = 0
		If g < 0 Then g = 0
		If b < 0 Then b = 0
		Return New Color(r / 255.0, g / 255.0, b / 255.0)
	End
	
	Method RenderTitleScreen(canvas:Canvas)
		canvas.Color = Color.White
		canvas.DrawImage(insectoidsLogo, VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 3)
		canvas.DrawImage(mx2Logo, VIRTUAL_RESOLUTION.X / 2, (VIRTUAL_RESOLUTION.Y / 2 + VIRTUAL_RESOLUTION.Y / 4) - mx2Logo.Height / 2)
		If gameTimer < 150 Or (gameTimer - 150) Mod 80 < 40
			canvas.Color = Color.White
			canvas.DrawText("PRESS SPACE TO START", VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y - font.Height * 2, .5, .5)
		End
		
	End

	Method RenderGameOver(canvas:Canvas)
		canvas.Color = Color.White
		canvas.DrawText("GAME OVER!", VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 2, .5, .5)
	End
	
	Method RenderGameWin(canvas:Canvas)
		canvas.Color = Color.White
		canvas.DrawText("GAME COMPLETE!", VIRTUAL_RESOLUTION.X / 2, VIRTUAL_RESOLUTION.Y / 2, .5, .5)
	End
	
	Method RenderStarField(canvas:Canvas)
		TileImage(canvas, starBackground, 0, starsScroll, VIRTUAL_RESOLUTION.X, VIRTUAL_RESOLUTION.Y)
		TileImage(canvas, starBackground, 7, starsScroll * 2, VIRTUAL_RESOLUTION.X, VIRTUAL_RESOLUTION.Y)
		TileImage(canvas, starBackground, 23, starsScroll * 3, VIRTUAL_RESOLUTION.X, VIRTUAL_RESOLUTION.Y)
	End
	
	Method RenderGame(canvas:Canvas)
		RenderStarField(canvas)		
		Alien.RenderAll(canvas)
		Bullet.RenderAll(canvas)
		If player Then player.Render(canvas)
		Bomb.RenderAll(canvas)
		Explosion.RenderAll(canvas)
	End

	Method OnMeasure:Vec2i() Override
		Return VIRTUAL_RESOLUTION
	End
End

Function Main()
	New AppInstance
	Insectoids = New InsectoidsApp
	App.Run()
End

Function CircleOverlap:Bool(pos1:Vec2f, radius1:Float, pos2:Vec2f, radius2:Float)
	Return ((pos2.X - pos1.X) * (pos2.X - pos1.X) + (pos2.Y - pos1.Y) * (pos2.Y - pos1.Y)) < (radius1 + radius2) * (radius1 + radius2)
End

Function TileImage(canvas:Canvas, image:Image, cameraX:Float, cameraY:Float, width:Int, height:Int)
	Local tileWidth:Int = image.Width
	Local tileHeight:Int = image.Height

	Local x := Int(cameraX) / tileWidth * tileWidth
	Local y := Int(cameraY) / tileHeight * tileHeight

	x += Int(cameraX) / tileWidth
	y += Int(cameraY) / tileHeight

	canvas.PushMatrix()

	canvas.Translate(-cameraX, -cameraY)

	For Local h := -2 Until width / tileWidth + 4
		For Local v := -2 Until height / tileHeight + 4
			canvas.DrawImage(image, x + h * tileWidth, y + v * tileHeight)
		Next
	Next
	canvas.PopMatrix()
End

Function GetFont:Font(path:String, size:Int, prefix:String = "asset::")
	path = prefix + path
	Local fnt:Font = Font.Load(path, size)
	If Not fnt
		Print("Error: Cant load font: " + path)
		App.Terminate()
	End
	Return fnt
End

Function GetSound:Sound(path:String, prefix:String = "asset::")
	path = prefix + path
	Local snd:Sound = Sound.Load(path)
	If Not snd
		Print("Error: Cant load sound: " + path)
		App.Terminate()
	End
	Return snd
End

Function GetImage:Image(path:String, setMidHandle:Bool = True, prefix:String = "asset::")
	path = prefix + path
	Local img:Image = Image.Load(path)
	If Not img
		Print("Error: Cant load image: " + path)
		App.Terminate()
	End
	If setMidHandle
		img.Handle = New Vec2f(.5)
	End
	Return img
End

Function LoadFrames:Image[] (path:String, numFrames:Int, cellWidth:Int, cellHeight:Int, padded:Bool = False)
	Local material := GetImage( path )
	If Not material Return New Image[0]
	
	If cellWidth * cellHeight * numFrames > material.Width * material.Height Return New Image[0]
	
	Local frames:= New Image[numFrames]
	
	If cellHeight = material.Height
		Local x:=0
		local width:=cellWidth
		If padded 
			x += 1
			width -= 2
		End if

		For Local i:=0 Until numFrames
			local rect:= New Recti(i * cellWidth + x, 0, i * cellWidth + x + width, cellHeight)
			frames[i] = New Image(material, rect)
		Next
	Else
		Local x:= 0, width:= cellWidth, y:= 0, height:= cellHeight
		Local columns:= material.Width / width
		If padded
			x += 1
			y += 1
			width -= 2
			height -= 2
		End If
		
		For Local i:=0 Until numFrames
			Local fx:Int = i Mod columns * cellWidth
			Local fy:Int = i / columns * cellHeight

			local rect:= New Recti(fx + x, fy + y, fx + x + width, fy + y + height)
			frames[i] = New Image(material, rect)
		Next
	End If
	
	Return frames
End

Function ToDegrees:Float(rad:Float)
	Return rad * 180.0 / Pi
End

Function ToRadians:Float(degree:Float)
	Return degree * Pi / 180.0
End

Function Cosd:Double(x:Double)
	Return Cos(ToRadians(x))
End
 
Function Sind:Double(x:Double)
	Return Sin(ToRadians(x))
End