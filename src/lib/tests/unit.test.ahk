#Include <Yunit\Yunit>
#Include <Yunit\Window>

if Main.testing
	Yunit.Use(YunitWindow).Test(QAKTests)

class QAKTests {

class QAKMenuTests {
	t1•SaveMenu()
	{
		static db := SQLite3('data.db')
		Main.Save()

		Yunit.Assert(db.Exec('SELECT * FROM items'))
	}

	t2•LoadMenu()
	{
		static db := SQLite3('data.db')
		menuList := Main.LoadMenu()
		Yunit.Assert(menuList is Map)
		Yunit.Assert(menuList.Count)
		Yunit.Assert(menuList.Has(0))

		menuList[0].Show()
	}
}

class QAKGuiTests {
	static begin() => true
	static end() => Main.MainGui.Destroy()

	t1•WindowIsCreated()
	{
		MainGui := Main.MainGui
		Yunit.Assert(WinExist(MainGui), 'gui exists')
		Yunit.Assert(MainGui.Title = 'Quick Access Knockoff', 'title check')
	}

	t2•WindowIsVisible()
	{
		static WS_VISIBLE := 0x10000000

		MainGui := Main.MainGui
		Yunit.Assert(WinExist(MainGui, 'gui exists'))

		Main.Show()
		MainGui.GetPos(&x,&y)
		MainGui.GetClientPos(unset, unset, &w, &h)
		Yunit.Assert(
			MainGui.size['x'] = x &&
			MainGui.size['y'] = y &&
			MainGui.size['width'] = w &&
			MainGui.size['height'] = h,
			'gui sizes'
		)

		if WinWaitActive(MainGui,,1)
			Yunit.Assert(true)
		else
			Yunit.Assert(WinGetStyle(MainGui) & WS_VISIBLE, 'gui visible')
	}

	t3•WindowIsHidden()
	{
		static WS_VISIBLE := 0x10000000

		MainGui := Main.MainGui
		Yunit.Assert(WinExist(MainGui, 'gui exists'))

		Main.Hide()
		Yunit.Assert(WinGetStyle(MainGui) & ~WS_VISIBLE, 'gui not visible')
	}

	t4•AddItemIsCreated()
	{
		Main.Add()
		AddGui := AddGui.gui
		Yunit.Assert(WinExist(AddGui), 'gui exists')
		Yunit.Assert(AddGui.Title = 'Add Item', 'title check')
		AddGui.Destroy()
	}
}

}