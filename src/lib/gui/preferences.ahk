class Preferences {
	static gui := Gui('', 'Preferences')

	static __New()
	{
		static mouse_buttons := ['Left Button', 'Middle Button', 'Right Button']

		Preferences.gui.AddGroupBox('xm r1.5 w365', 'Show Menu')
		Preferences.gui.AddCheckbox('vsmw xp+10 yp+20', 'Win')
		Preferences.gui.AddCheckbox('vsmc x+m', 'Ctrl')
		Preferences.gui.AddCheckbox('vsms x+m', 'Shift')
		Preferences.gui.AddCheckbox('vsma x+m', 'Alt')
		Preferences.gui.AddDropDownList('vsmButton x+m yp-3 w150', mouse_buttons).Choose(1)
		
		Preferences.gui.AddGroupBox('xm r1.5 w365', 'Customize Menu')
		Preferences.gui.AddCheckbox('vcmw xp+10 yp+20', 'Win')
		Preferences.gui.AddCheckbox('vcmc x+m', 'Ctrl')
		Preferences.gui.AddCheckbox('vcms x+m', 'Shift')
		Preferences.gui.AddCheckbox('vcma x+m', 'Alt')
		Preferences.gui.AddDropDownList('vcmButton x+m yp-3 w150', mouse_buttons).Choose(1)
		
		xloc := 365 - 75*2
		Preferences.gui.AddButton('x' xloc ' w75', 'Save').OnEvent('Click', (*)=>Preferences.SaveHotkeys())
		Preferences.gui.AddButton('x+m w75', 'Cancel').OnEvent('Click', (*)=>Preferences.Cancel())
	}

	static Show() => (Preferences.loadHotkeys(), Preferences.gui.Show())
	static Cancel() => Preferences.gui.Hide()

	static LoadPreferences()
	{
		db := Main.db
		table := db.Exec('SELECT key,value FROM preferences')

		loop table.nRows
		{
			key := table.cell[A_Index, 'key']
			value := table.cell[A_Index, 'value']

			Main.preferences.%key% := value
		}
	}

	static SaveHotkeys()
	{
		db := Main.db

		Hotkey Main.preferences.show_menu, 'Off'
		Hotkey Main.preferences.customize_menu, 'Off'

		smMods   := (
			(Preferences.gui['smw'].value ? '#' : '')
			(Preferences.gui['smc'].value ? '^' : '')
			(Preferences.gui['sms'].value ? '+' : '')
			(Preferences.gui['sma'].value ? '!' : '')
		)
		smButton := RegExReplace(Preferences.gui['smButton'].text, '(\w).*\s(.*)$', '$1$2')
		
		cmMods   := (
			(Preferences.gui['cmw'].value ? '#' : '')
			(Preferences.gui['cmc'].value ? '^' : '')
			(Preferences.gui['cms'].value ? '+' : '')
			(Preferences.gui['cma'].value ? '!' : '')
		)
		cmButton := RegExReplace(Preferences.gui['cmButton'].text, '(\w).*\s(.*)$', '$1$2')

		SQL := 
		(Ltrim
			'INSERT OR REPLACE INTO preferences
			VALUES(1, "show_menu", "' smMods smButton '"),
			(1, "customize_menu", "' cmMods cmButton '");'
		)
		
		try db.Exec(SQL)
		Preferences.gui.Submit()
		Preferences.loadHotkeys()
	}

	static loadHotkeys()
	{
		Preferences.LoadPreferences()

		Hotkey Main.preferences.show_menu, (*)=> Main.menu["0"].Show(), 'On'
		Hotkey Main.preferences.customize_menu, (*)=> Main.gui.Show(), 'On'
		
		if InStr(Main.preferences.show_menu, '#')
			Preferences.gui['smw'].value := true
		if InStr(Main.preferences.show_menu, '^')
			Preferences.gui['smc'].value := true
		if InStr(Main.preferences.show_menu, '+')
			Preferences.gui['sms'].value := true
		if InStr(Main.preferences.show_menu, '!')
			Preferences.gui['sma'].value := true
		
		Preferences.gui['smButton'].Choose(RegExReplace(Main.preferences.show_menu, '[#^+!]+(\w)Button', '$1'))
		
		if InStr(Main.preferences.customize_menu, '#')
			Preferences.gui['cmw'].value := true
		if InStr(Main.preferences.customize_menu, '^')
			Preferences.gui['cmc'].value := true
		if InStr(Main.preferences.customize_menu, '+')
			Preferences.gui['cms'].value := true
		if InStr(Main.preferences.customize_menu, '!')
			Preferences.gui['cma'].value := true
		
		Preferences.gui['cmButton'].Choose(RegExReplace(Main.preferences.customize_menu, '[#^+!]+(\w)Button', '$1'))

		Main.LoadTrayMenu()
	}
}