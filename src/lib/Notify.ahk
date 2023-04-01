class Notify {
	static Show(text, title, bgColor := 'White', txtColor := 'Black')
	{
		splash := gui('-Caption +AlwaysOnTop +Border')
		splash.BackColor := bgColor
		
		WinSetTransparent 0, splash

		splash.SetFont('s14', 'Bahnschrift')
		splash.AddText('w250 c' txtColor ' Center', title)
		splash.SetFont('s12', 'Bahnschrift')
		splash.AddText('w250 c' txtColor ' Center y+5', text)
		splash.Show()
		
		loop 100
		{
			try WinSetTransparent Floor(A_Index * 15), splash
			Sleep 1
		}
		
		loop 255
			WinSetTransparent 255-A_Index, splash
		
		splash.Destroy()
	}
}