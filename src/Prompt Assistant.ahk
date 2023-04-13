#SingleInstance

#Include <SQLite\SQLite3>

#Include <Base64\Base64>
#Include <HandleFromBase64\HandleFromBase64>

#Include <Notify>
#Include <gui\AddGui>
#Include <gui\preferences>

; TODO: Export only selected

TraySetIcon 'res\ico\PA.ico'

class Main {
	static testing       := false

	static gui           := Gui(unset, 'Prompt Assistant')
	static menu          := ''
	static preferences   := {}
	static LVHeaders     := ['Type', 'Label', 'Hotkey', 'Hotstring', 'Snippet', 'id', 'Parent', 'b64Icon', 'Pos']
	static lvInfo        := Map()
	static tvInfo        := Map()
	static tvpInfo       := Map()
	static db            := SQLite3(A_UserName = 'RaptorX' ? 'dataTEST.db' : 'data.db', 
	                                A_IsCompiled ? A_ScriptDir '\lib\Sqlite\bin\sqlite3' (A_PtrSize * 8) '.dll' : unset)
	static Icon          := {list:IL_Create(10,10), data:Map()}
	static tmpIcon       := A_Temp '\temp.ico'

	static __New()
	{
		static db := Main.db
		static tvInfo  := Main.tvInfo

		static BS_ICON     := 0x40
		static BS_FLAT     := 0x8000
		static BM_SETIMAGE := 0xF7
		static WM_SETCURSOR := 0x0020

		SQL :=
		(
		'--
		-- File generated with SQLiteStudio v3.3.3 on Thu Mar 2 10:42:09 2023
		--
		-- Text encoding used: System
		--
		PRAGMA foreign_keys = off;
		BEGIN TRANSACTION;

		-- Table: items
		CREATE TABLE IF NOT EXISTS items (type INTEGER, label STRING, hotkey STRING, hotstring STRING, snippet STRING, id INTEGER PRIMARY KEY UNIQUE, parent INTEGER, b64icon STRING, pos INTEGER);

		-- Table: preferences
		CREATE TABLE IF NOT EXISTS preferences ("type" INTEGER, "key" STRING PRIMARY KEY UNIQUE, value STRING);
		INSERT OR IGNORE INTO preferences ("type", "key", value)
		VALUES (0, "display", 1),(1, "show_menu", "#RButton"),(1, "customize_menu", "#+RButton");

		COMMIT TRANSACTION;
		PRAGMA foreign_keys = on;'
		)

		db.Exec(SQL)
		Preferences.loadHotkeys()

		OnMessage(WM_SETCURSOR, ObjBindMethod(Main, 'InfoTooltips'))

		lvWidth := 650
		tvWidth := lvWidth / 4

		Main.gui.AddText('ym w' tvWidth ' Section', 'Submenus:')
		Main.gui.SetFont('', 'Arial')
		Main.gui.AddTreeView('vsmTree w' tvWidth ' h400 -Buttons')
		Main.gui.SetFont()
		Main.gui['smTree'].OnEvent('Click', (obj,info)=>Main.TVSelect(info))
		Main.gui['smTree'].SetImageList(Main.Icon.list)

		Main.gui.AddText('x+-1 ys', 'Items:')
		Main.gui.SetFont('', 'Arial')
		Main.gui.AddListView('vmenu w' lvWidth ' h400', Main.LVHeaders)
		Main.gui.SetFont()
		Main.gui['menu'].SetImageList(Main.Icon.list)
		Main.gui['menu'].OnEvent('Click', (*)=>Main.SetButtonStatus())
		Main.gui['menu'].OnEvent('DoubleClick', (*)=>Main.SelectEdit())

		IL_Add(Main.Icon.list, 'C:\WINDOWS\system32\imageres.dll', 76)

		btnISize := 24
		buttons := [
			'Add','Edit Disabled', 'Delete Disabled', 'MoveUp Disabled',
			'MoveDown Disabled'
		]

		for button in buttons
			Main.gui.AddButton( 'v' button (A_Index = 1 ? ' x+5' : '' )
			                 . ' w' btnISize + 12
			                 . ' h' btnISize + 12
			                 . ' +' BS_ICON)

		basicBtnLoc := tvWidth + lvWidth - (75 * 2) - 110 - 10
		Main.gui.AddButton('xm w75 h' btnISize + 12, 'Import').OnEvent('Click', (*)=>Main.Import())
		Main.gui.AddButton('x+m w75 h' btnISize + 12, 'Export').OnEvent('Click', (*)=>Main.Export())

		Main.gui.AddButton('x' basicBtnLoc ' yp  w75 h' btnISize + 12, 'Save').OnEvent('Click', (*)=>Main.Save())
		Main.gui.AddButton('x+m w110 h' btnISize + 12, 'Save && Close')
		        .OnEvent('Click', (*)=>(Main.gui.Hide(), Main.Save()))
		Main.gui.AddButton('x+m w75 h' btnISize + 12, 'Cancel').OnEvent('Click', (*)=>Main.Cancel())

		Main.gui['Add'].OnEvent('Click', (obj,info)=>Main.Add(obj))
		Main.gui['Edit'].OnEvent('Click', (obj,info)=>Main.Edit(obj))

		Main.gui['Delete'].OnEvent('Click', (*)=>Main.Delete())
		Main.gui['MoveUp'].OnEvent('Click', (obj, info)=>Main.MoveRow(obj, info))
		Main.gui['MoveDown'].OnEvent('Click', (obj, info)=>Main.MoveRow(obj, info))

		btnIcons := Map(
			'029-add-3.ico'     , Main.gui['Add'],
			'028-cancel-1.ico'  , Main.gui['Delete'],
			'022-edit-1.ico'    , Main.gui['Edit'],
			'027-up-arrow.ico'  , Main.gui['MoveUp'],
			'026-down-arrow.ico', Main.gui['MoveDown'],
			'005-import.ico'    , Main.gui['Import'],
			'006-export.ico'    , Main.gui['Export'],
		)

		for name,ctrl in btnIcons
			SendMessage BM_SETIMAGE, true,
			            LoadPicture('res\ico\' name, 'w' btnISize ' h' btnISize, &type), ctrl

		hIcon := LoadPicture("C:\WINDOWS\system32\shell32.dll", "Icon297", &imgType)
		hIcon := LoadPicture("C:\WINDOWS\system32\shell32.dll", "Icon132", &imgType)


		btnIcons := Map(
			Main.gui['Save'], 297,
			Main.gui['Cancel'], 132,
		)

		for ctrl,icon in btnIcons
			SendMessage BM_SETIMAGE, true,
			            LoadPicture('C:\WINDOWS\system32\shell32.dll', 'w' btnISize ' h' btnISize ' Icon' icon, &type), ctrl
		
		SendMessage BM_SETIMAGE,
		            true,
		            LoadPicture('C:\WINDOWS\system32\comres.dll', 'w' btnISize ' h' btnISize ' Icon5', &type),
			    Main.gui['Save && Close']

		Main.loadView()
		Main.LoadMenu()
		Main.LoadMenuBar()
		Main.LoadTrayMenu()

		Main.gui.Show('hide')
		Main.gui.GetPos(&x, &y)
		Main.gui.GetClientPos(unset, unset, &w, &h)
		Main.gui.size := Map('x', x, 'y', y, 'width', w-1, 'height', h)
		Main.gui.diff := Map('x', 0, 'y', 0, 'width', 0  , 'height', 0)


		if Main.preferences.display
			Main.gui.Show('w' Main.gui.size['width'])
	}

	static Show(options?) => Main.gui.Show(options??'')
	static Hide() => Main.gui.Hide()

	static LoadTrayMenu()
	{
		show_menu := Main.HKToString(Main.preferences.show_menu)
		customize_menu := Main.HKToString(Main.preferences.customize_menu)
		
		A_TrayMenu.Delete()
		A_TrayMenu.Add('Show Menu`t' show_menu , (*)=> Main.menu["0"].Show())
		A_TrayMenu.Add('Customize Menu`t' customize_menu, (*)=> Main.gui.show())
		A_TrayMenu.Add()
		A_TrayMenu.AddStandard()
	}

	static BuildTVPath(id)
	{
		while pID := Main.gui['smTree'].GetParent(pID ?? id)
			path := Main.gui['smTree'].GetText(pID) ' > ' (path ?? '')

		path .= Main.gui['smTree'].GetText(id)
		return [path]
	}

	static Add(button)
	{
		AddGui.gui['AddBtn'].text := 'Add'
		AddGui.gui['Icon'].value := AddGui.placeholder

		AddGui.gui.b64Icon := ''
		AddGui.gui['Label'].value := ''
		AddGui.gui['Hotstring'].value := ''
		AddGui.gui['Hotkey'].value := ''
		AddGui.gui['Snippet'].value := ''
		AddGui.Show(button)
	}

	/**
	 * Displays the edit dialog
	 */
	static Edit(button)
	{
		static db := Main.db
		static tvpInfo := Main.tvpInfo

		if row := Main.gui['menu'].GetNext(0)
			id  := Main.gui['menu'].GetText(row, 6)
		else
			id := Main.tvpInfo[Main.gui['smTree'].GetSelection()]

		AddGui.gui['AddBtn'].text := 'Update'
		AddGui.editing := {id: id, row:row}

		switch Main.lvInfo[id][1]
		{
		case 'TXT':
			ControlSetChecked true, 'Button4', AddGui.gui
		case 'MENU':
			ControlSetChecked true, 'Button5', AddGui.gui
		}

		/**
		Using ControlSetChecked below triggers the Event associated with
		the radio buttons, so we need to make sure that the icons are set
		prior to that event handler being called
		 */
		b64icon := Main.lvInfo[id][8]
		if b64icon
		{
			try FileDelete Main.tmpIcon
			FileAppend B64Decode(b64icon, 'RAW'), Main.tmpIcon
			AddGui.gui['Icon'].value := Main.tmpIcon ; 'HBITMAP:' HandleFromBase64(b64icon, false)
		}
		else
			AddGui.gui['Icon'].value := AddGui.placeholder

		AddGui.gui.b64Icon := b64icon
		AddGui.gui['Label'].value := Main.lvInfo[id][2]
		AddGui.gui['Hotkey'].value := Main.lvInfo[id][3]
		AddGui.gui['Hotstring'].value := Main.lvInfo[id][4]
		AddGui.gui['Snippet'].value := SQLite3.UnEscape(Main.lvInfo[id][5])
		AddGui.Show(button)

	}

	static Cancel()
	{
		Main.gui.Hide()
		Main.loadView()
	}

	static Save()
	{
		static db := Main.db
		static lvInfo := Main.lvInfo
		static tvInfo := Main.tvInfo
		static SQL := "INSERT OR REPLACE INTO items VALUES({});"

		Main.ResetTriggers()
		db.Exec('BEGIN TRANSACTION;')
		db.Exec('DELETE FROM items;')
		for id,item in lvInfo
		{
			pos := A_Index
			; Instead a replace from tab to comma for using CSV
			; i decided to go on each field to make sure the text
			; is escaped before inserting into the database
			values := ""
			for value in item
			{
				switch A_Index {
					case 3:
						values .= "'" Main.StringToHK(value) "',"
					case 4:
						if item[1] = 'MENU'
							values .= "'',"
						else
							values .= "'" SQLite3.Escape(value) "',"
					default:
						values .= "'" SQLite3.Escape(value) "',"
				}
			}

			db.Exec(Format(sql, Trim(values, ',')))
		}
		db.Exec('COMMIT TRANSACTION;')

		Main.loadView()
		Main.LoadMenu()

		Notify.Show('Menu Saved.', 'Success', 0x52efac)
	}

	static Import()
	{
		static db := Main.db
		static SQL := 'INSERT INTO items VALUES({})'

		if !import_from := FileSelect(1,, 'Select file to Import', 'Tab Delimited (*.tsv)')
			return

		SplitPath import_from, &file_name
		RegExMatch(file_name, '^(?<name>.*?)-', &matched)
		if !matched || !menu_name := matched['name']
			if !menu_name := InputBox('Set the name of your menu', 'Menu Name', 'w200 h90').value
				return Notify.Show('You must specify a menu name.`nAborting', 'Error',
				                   'Red', 'White')


		lines := StrSplit(FileRead(import_from, 'utf-8 `n'), '`n')

		; hFile := FileOpen(import_from, 'r', 'UTF-8')
		; headers := hFile.ReadLine()
		if !(lines[1] ~= 'i)"?Type"?`t"?Label"?`t"?Hotkey"?`t"?Hotstring"?`t"?Snippet"?`t"?id"?`t"?Parent"?`t"?b64Icon"?`t"?pos"?')
		{
			Notify.Show('Invalid menu file', 'Error','Red', 'White')
			return ; hFile.Close()
		}

		db.Exec('BEGIN TRANSACTION')
		for line in lines ; := hFile.ReadLine()
		{
			if A_Index = 1 || !line
				continue

			A_Clipboard := line
			try db.Exec(fsql := Format(SQL, A_Clipboard:=StrReplace(line, A_Tab, ',')))
			catch
			{
				A_Clipboard := fsql
				throw Error(db.errMsg, A_ThisFunc)
			}
		}
		db.Exec('COMMIT TRANSACTION')
		; hFile.Close()

		Main.gui['menu'].Delete()
		Main.gui['smTree'].Delete()

		Main.loadView()
		Main.LoadMenu()
	}

	static Export()
	{
		static lvInfo := Main.lvInfo
		static tvpInfo := Main.tvpInfo

		root_ID := Main.gui['smTree'].GetSelection()
		if !export_to := FileSelect('S24', Main.gui['smTree'].GetText(root_ID) '-menu-export.tsv','Save as', 'Tab Delimited (*.tsv)')
			return
		else if export_to ~= '\.tsv$' = 0
			export_to .= '.tsv'

		hFile := FileOpen(export_to, 'w-', 'UTF-8')

		for header in Main.LVHeaders
			headers .= '"' header '"' A_Tab

		hFile.Write(Trim(headers, A_Tab) '`n')


		export_items := Main.GetFullTree(tvpInfo[root_ID])

		for id in export_items
		{
			line := ''
			for value in lvInfo[id]
			{
				value := SQLite3.Escape(value)
				if A_Index = 3
					line .= '"' Main.StringToHK(value) '"' A_Tab
				else if A_Index = 7
				&& id == tvpInfo[root_ID]
					line .= 0 A_Tab
				else
					line .= '"' value '"' A_Tab
			}

			hFile.Write(Trim(line, A_Tab) '`n')
		}

		hFile.Close()

		if FileExist(export_to)
			Notify.Show('Export Successful', 'Success', 0x52efac)
		else
			Notify.Show('There was a problem saving the file', 'Error', 'Red', 'White')
	}

	static GetFullTree(parent)
	{
		static level := 0
		static lvInfo := Main.lvInfo

		level++
		if level = 1
			lvInfo['MARKED'] := Map()

		for itemID, item in lvInfo
		{
			if itemID = 'MARKED'
				continue

			if item[6] = parent
			|| item[7] = parent
			{
				lvInfo['MARKED'][itemID] := true

				if item[1] = 'MENU'
				&& itemID != parent
					Main.GetFullTree(item[6])
			}
		}

		level--
		if level = 0
		{
			items := lvInfo['MARKED']
			lvInfo.Delete('MARKED')
			return items
		}

	}

	static Delete()
	{
		static lvInfo  := Main.lvInfo
		static tvInfo  := Main.tvInfo
		static tvpInfo := Main.tvpInfo

		while row  := Main.gui['menu'].GetNext()
		{
			id   := Main.gui['menu'].GetText(row, 6)
			type := Main.gui['menu'].GetText(row, 1)
			Main.gui['menu'].Delete(row)

			marked_items := Main.GetFullTree(id)

			for itemID in marked_items
				lvInfo.Delete(itemID)

			if type = 'MENU'
			{
				Main.gui['smTree'].Delete(tvInfo[id])
				if !row
					Main.TVSelect(parent)
			}
		}
		else
		{
			id     := tvpInfo[tvID := Main.gui['smTree'].GetSelection()]
			parent := Main.gui['smTree'].GetParent(tvID)

			type := lvInfo[id][1]
			Main.gui['menu'].Delete()

			marked_items := Main.GetFullTree(id)

			for itemID in marked_items
				lvInfo.Delete(itemID)

			if type = 'MENU'
			{
				Main.gui['smTree'].Delete(tvInfo[id])
				if !row
					Main.TVSelect(parent)
			}
		}

		Main.ResetPos()
		Main.gui['Edit'].Enabled := false
		Main.gui['Delete'].Enabled := false
	}

	static ResetPos()
	{
		loop Main.gui['menu'].GetCount()
		{
			current_id := Main.gui['menu'].GetText(A_Index, 6)
			Main.lvInfo[current_id][9] := A_Index
			Main.gui['menu'].Modify(A_Index, '', Main.lvInfo[current_id]*)
		}
		Main.gui['menu'].ModifyCol(9, 'Sort')
	}

	static MarkForDelete(parent)
	{
		static lvInfo  := Main.lvInfo

		if !lvInfo.Has('DELETED')
			lvInfo['DELETED'] := Map()

		for itemID, item in lvInfo
		{
			if itemID = 'DELETED'
				continue

			if item[6] = parent
			|| item[7] = parent
			{
				lvInfo['DELETED'][item[6]] := true

				if item[1] = 'MENU'
				&& item[6] != parent
					Main.MarkForDelete(item[6])
			}
		}
	}

	static LoadMenuBar()
	{
		Main.gui.MenuBar := MenuBar()

		preferences_menu := Menu()
		; about       := Menu()

		preferences_menu.Add('Display On Startup', preferencesHandler)
		preferences_menu.Add()
		preferences_menu.Add('Hotkeys', (*)=>Preferences.Show())
		; about.Add('Help', menuHandler)
		; about.Add('About', menuHandler)

		Main.gui.menuBar.Add('Preferences', preferences_menu)
		; Main.gui.menuBar.Add('About', about)


		if Main.preferences.display
			preferences_menu.Check('Display On Startup')

	}

	static LoadMenu()
	{
		static db := Main.db

		Main.menu := Map()
		Main.menu['0'] := Main.BuildsmTree({id:0, menu: Menu()})
		Main.menu['0'].Add()
		Main.menu['0'].Add('Customize', menuHandler)
		Main.menu['0'].SetIcon('Customize', "res\ico\settings.ico")
	}

	static BuildsmTree(parent)
	{
		static level         := 0
		static db            := Main.db

		level++
		SQL := 'SELECT * FROM items WHERE parent=' parent.id ' ORDER BY parent,pos ASC'

		try table := db.Exec(SQL)
		catch
			throw Error(db.errMsg, A_ThisFunc)

		loop table.nRows
		{
			sub := {
				menu     : Menu(),
				id       : table.cell[A_Index, 'id'],
				label    : table.cell[A_Index, 'label'],
				type     : table.cell[A_Index, 'type'],
				hotkey   : table.cell[A_Index, 'hotkey'],
				hotstring: table.cell[A_Index, 'hotstring'],
				b64icon  : table.cell[A_Index, 'b64icon']
			}

			; extra := '`t`t' (sub.hotstring ? '🟨 ' sub.hotstring : '')
			;       .         (sub.hotkey && sub.hotstring ? '  ' : '')
			;       .         (sub.hotkey ? '🟡 ' sub.hotkey : '')
			extra := '`t' (sub.hotstring && sub.type != 'MENU' ? '🟨 ' sub.hotstring : '')
			      .       (sub.hotkey && sub.hotstring ? '    ' : '')
			      .       (sub.hotkey ? '💠 ' Main.HKToString(sub.hotkey) : '')
			; extra := '`t`t⚫ ' sub.hotstring (sub.hotkey && sub.hotstring ? '  ' : '') '🟡 ' sub.hotkey
			; extra := '`t`t🔰 ' sub.hotstring (sub.hotkey && sub.hotstring ? '  ' : '') '💠 ' sub.hotkey
			switch sub.type
			{
			case 'TXT':
				parent.menu.Add(sub.label '`t' extra, menuHandler)
				if sub.b64icon
					parent.menu.SetIcon(sub.label '`t' extra, 'HICON:' HandleFromBase64(sub.b64icon))
			case 'MENU':
				Main.menu[sub.id] := sub.menu
				Main.BuildsmTree(sub)
				parent.menu.Add(sub.label '`t' extra, sub.menu)
				if sub.b64icon
					parent.menu.SetIcon(sub.label '`t' extra, 'HICON:' HandleFromBase64(sub.b64icon))
			}

			try
			{
				if sub.hotkey
					Hotkey sub.hotkey, hotkeyHandler, 'On'

				if sub.hotstring
					Hotstring '::' sub.hotstring, hotstringHandler, 'On'
			}
			catch Error as e
				OutputDebug e.Message ': ' sub.hotkey ' - ' sub.hotstring
		}

		level--
		return parent.menu
	}

	static LoadTree(table, new_parent?)
	{
		Main.gui['smTree'].Opt('-Redraw')
		loop table.nRows
		{
			icon_index := unset
			id := table.cell[A_Index, 'id']
			if b64icon := table.cell[A_Index, 'b64Icon']
			{
				if Main.Icon.data.Has(id)
					icon_index := Main.Icon.data[id]
				else
					icon_index := IL_Add(Main.Icon.list, 'HICON:' HandleFromBase64(b64icon))
			}

			parent := new_parent ?? Main.tvInfo[table.cell[A_Index, 'parent']]
			label := table.cell[A_Index, 'label']

			tvID := Main.gui['smTree'].Add(label, parent,'Expand Icon' (icon_index ?? -1))

			Main.tvInfo.Set(id, tvID)
			Main.tvpInfo.Set(tvID, id)
			Main.Icon.data.Set(id, icon_index ?? -1)
		}
		Main.gui['smTree'].Opt('+Redraw')
	}

	static LoadList(table)
	{
		Main.gui['menu'].Opt('-Redraw')
		Main.gui['menu'].Delete()
		loop table.nRows
		{
			icon_index := unset
			id := table.cell[A_Index, 'id']
			; hk := table.cell[A_Index, 'hotkey']
			if b64icon := table.cell[A_Index, 'b64icon']
				icon_index := IL_Add(Main.Icon.list, 'HICON:' HandleFromBase64(b64icon))

			table.cell[A_Index, 'hotkey'] := Main.HKToString(table.cell[A_Index, 'hotkey'])

			if table.cell[A_Index, 'type'] = 'MENU'
			{
				table.cell[A_Index, 'hotstring'] := '----'
				table.cell[A_Index, 'Snippet']   := '----------------------------'
			}

			; table.rows[A_Index][table.header['hotkey']] := Main.HKToString(table.cell[A_Index, 'hotkey'])
			Main.lvInfo.Set(id, table.rows[A_Index])

			pos := Main.gui['menu'].Add('Icon' (icon_index ?? -1), table.rows[A_Index]*)
			Main.Icon.data.Set(id, icon_index ?? -1)
		}

		Main.AutoFitColumns()
		Main.gui['menu'].Opt('+Redraw')
	}

	static loadView()
	{
		static db      := Main.db
		static lvInfo  := Main.lvInfo
		static tvInfo  := Main.tvInfo
		static tvpInfo := Main.tvpInfo

		Main.gui['smTree'].Delete()

		tvInfo.Set("0", tvID := Main.gui['smTree'].Add('Main', 0,'Icon1 Expand'))
		tvpInfo.Set(tvID, "0")
		Main.gui['smTree'].Modify(tvID, 'Select')

		SQL := "SELECT id,label,parent,b64icon FROM items WHERE type='MENU' ORDER BY parent,pos ASC"
		try table := db.Exec(SQL)
		catch
			throw Error(db.errMsg, A_ThisFunc)

		Main.LoadTree(table)

		SQL := "SELECT * FROM items WHERE parent=0 ORDER BY parent,pos ASC"
		try table := db.Exec(SQL)
		catch
			throw Error(db.errMsg, A_ThisFunc)

		Main.LoadList(table)

		SQL := "SELECT * FROM items WHERE parent is not 0 ORDER BY parent,pos ASC"
		try table := db.Exec(SQL)
		catch
			throw Error(db.errMsg, A_ThisFunc)

		loop table.nRows
		{
			icon_index := unset
			id := table.cell[A_Index, 'id']
			if b64icon := table.cell[A_Index, 'b64icon']
				icon_index := IL_Add(Main.Icon.list, 'HICON:' HandleFromBase64(b64icon))

			table.rows[A_Index][table.header['hotkey']] := Main.HKToString(table.cell[A_Index, 'hotkey'])
			lvInfo.Set(table.cell[A_Index, 'id'], table.rows[A_Index])
			Main.Icon.data.Set(id, icon_index ?? -1)
		}
	}

	static AutoFitColumns()
	{
		; ['Label', 'Type', 'Text', 'Hotstring', 'Hotkey', 'id', 'Parent', 'b64Icon']
		loop Main.gui['menu'].GetCount('Col')
			Main.gui['menu'].ModifyCol(A_Index, A_Index ~= '(6|7|8|9)' ? 0 : 'AutoHdr')

		Main.gui['menu'].ModifyCol(3, 'Center')
		Main.gui['menu'].ModifyCol(4, 'Center')
		Main.gui['menu'].ModifyCol(5, '300')
	}

	static ResetTriggers()
	{
		static db := Main.db

		SQL := "SELECT hotkey,hotstring FROM items WHERE hotkey != '' or hotstring != ''"
		try table := db.Exec(SQL)
		catch
			throw Error(db.errMsg, A_ThisFunc)

		loop table.nRows
		{
			hk := table.cell[A_Index, 'hotkey']
			hs := table.cell[A_Index, 'hotstring']

			try
			{
				if hk
					Hotkey hk, 'Off'
				if hs
					Hotstring '::' hs, 'Off'
			}
		}
	}

	static TVSelect(tvItem)
	{
		static db := Main.db
		static lvInfo  := Main.lvInfo
		static tvInfo  := Main.tvInfo
		static tvpInfo := Main.tvpInfo

		if !tvItem
			return

		Main.gui['smTree'].Opt('+Redraw')
		Main.gui['menu'].Opt('-Redraw')
		Main.gui['menu'].Delete()

		for id,row in lvInfo
		{
			icon_index := unset
			if row[7] = tvpInfo[tvItem]
			{
				icon_index := Main.Icon.data[id]

				if row[1] = 'MENU'
				{
					row[4] := '----'
					row[5] := '----------------------------'
				}

				pos := Main.gui['menu'].Add('Icon' (icon_index), row*)
			}
		}

		Main.gui['menu'].ModifyCol(9, 'Sort')
		Main.AutoFitColumns()
		Main.gui['menu'].Opt('+Redraw')

		Main.gui['MoveUp'].Enabled   := false
		Main.gui['MoveDown'].Enabled := false

		try
		{
			Main.gui['Edit'].Enabled     := Main.gui['smTree'].GetText(tvItem) = 'Main' ? false : true
			Main.gui['Delete'].Enabled   := Main.gui['smTree'].GetText(tvItem) = 'Main' ? false : true
		}
		catch
		{
			Main.gui['Edit'].Enabled     := false
			Main.gui['Delete'].Enabled   := false
		}
	}

	static SetButtonStatus()
	{
		if !Main.tvpInfo.Has(selection := Main.gui['smTree'].GetSelection())
			return

		Main.gui['Edit'].Enabled     := Main.gui['menu'].GetNext() ? true : false
		Main.gui['MoveUp'].Enabled   := Main.gui['menu'].GetNext() ? true : false
		Main.gui['MoveDown'].Enabled := Main.gui['menu'].GetNext() ? true : false
		Main.gui['Delete'].Enabled   := Main.gui['menu'].GetNext() || Main.tvpInfo[selection] != 0 ? true : false
	}

	/**
	* Decides whether to show the edit dialog or
	* simply fill the list view with the contents of the submenu
	*/
	static SelectEdit()
	{
		row := Main.gui['menu'].GetNext(0)
		id  := Main.gui['menu'].GetText(row, 6)

		switch Main.lvInfo[id][1]
		{
		case 'TXT':
			Main.Edit(Main.gui['Edit'])
		case 'MENU':
			tvID := Main.tvInfo[id]

			Main.gui['smTree'].Modify(tvID, 'Select')
			Main.TVSelect(tvID)
		}

	}

	static MoveRow(obj, info)
	{
		if !row := Main.gui['menu'].GetNext()
			return

		switch obj
		{
		case Main.gui['MoveUp']:
			if row = 1
				return

			prev_row := row - 1
			id := Main.gui['menu'].GetText(row, 6)
			prev_id := Main.gui['menu'].GetText(prev_row, 6)

			Main.lvInfo[id][9]--
			Main.lvInfo[prev_id][9]++

			Main.gui['menu'].Modify(row, '', Main.lvInfo[id]*)
			Main.gui['menu'].Modify(prev_row, '', Main.lvInfo[prev_id]*)
			Main.gui['menu'].ModifyCol(9, 'Sort')
		case Main.gui['MoveDown']:
			if row = Main.gui['menu'].GetCount()
				return

			next_row := row + 1
			id := Main.gui['menu'].GetText(row, 6)
			next_id := Main.gui['menu'].GetText(next_row, 6)

			Main.lvInfo[id][9]++
			Main.lvInfo[next_id][9]--

			Main.gui['menu'].Modify(row, '', Main.lvInfo[id]*)
			Main.gui['menu'].Modify(next_row, '', Main.lvInfo[next_id]*)
			Main.gui['menu'].ModifyCol(9, 'Sort')
		}
	}

	static InfoTooltips(wParam, lParam, msg, hwnd)
	{
		MouseGetPos ,,,&hwnd, 2

		switch hwnd
		{
		case Main.gui['Add'].hwnd:
			return ToolTip('Add new item')
		case Main.gui['Edit'].hwnd:
			return ToolTip('Edit selected item')
		case Main.gui['Delete'].hwnd:
			return ToolTip('Delete selected item')
		case Main.gui['MoveUp'].hwnd:
			return ToolTip('Move selected item Up')
		case Main.gui['MoveDown'].hwnd:
			return ToolTip('Move selected item Down')
		}
		ToolTip
	}

	static HKToString(hk)
	{
		if !hk
			return

		temphk := []

		if InStr(hk, '#')
			temphk.Push('Win+')
		if InStr(hk, '^')
			temphk.Push('Ctrl+')
		if InStr(hk, '+')
			temphk.Push('Shift+')
		if InStr(hk, '!')
			temphk.Push('Alt+')

		hk := RegExReplace(hk, '[#^+!]')
		for mod in temphk
			fixedMods .= mod

		return fixedMods StrUpper(hk)
	}

	static StringToHK(str)
	{
		fixedHK := StrReplace(str, 'Shift+', '+')
		fixedHK := StrReplace(fixedHK, 'Ctrl+', '^')
		fixedHK := StrReplace(fixedHK, 'Alt+', '!')
		fixedHK := StrReplace(fixedHK, 'Win+', '#')

		return StrLower(fixedHK)
	}
}

menuHandler(ItemName, ItemPos, MyMenu)
{
	static db := Main.db

	if ItemName = 'Customize'
		return Main.gui.Show()

	SQL := "SELECT type,parent,snippet FROM items WHERE label='" RegExReplace(ItemName, '`t.*') "'"

	items := db.Exec(SQL)
	loop items.nRows
	{
		if MyMenu.handle != Main.menu[t:=items.cell[A_Index, 'parent']].Handle
			continue

		itemRow := A_Index
		break
	}

	performAction(items.cell[itemRow, 'type'], items.cell[itemRow, 'snippet'])
}

preferencesHandler(ItemName, ItemPos, MyMenu)
{
	static db := Main.db

	switch ItemName
	{
	case 'Display On Startup':
		Main.preferences.display := !Main.preferences.display
		MyMenu.ToggleCheck(ItemName)

		SQL := 'UPDATE preferences SET value=' Main.preferences.display ' WHERE key="display"'
		db.Exec(SQL)
	}
}

hotstringHandler(trigger)
{
	static db := Main.db

	SQL := "SELECT type,parent,snippet FROM items WHERE hotstring='" RegExReplace(trigger, '^::') "'"
	item := db.Exec(SQL)
	performAction(item.cell[1, 'type'], item.cell[1, 'snippet'])

}

hotkeyHandler(trigger)
{
	static db := Main.db

	SQL := "SELECT type,parent,snippet FROM items WHERE hotkey='" trigger "'"
	item := db.Exec(SQL)
	performAction(item.cell[1, 'type'], item.cell[1, 'snippet'])

}

performAction(type, action)
{
	switch type
	{
	case 'TXT':
		oldClip := ClipboardAll()
		A_Clipboard := SQLite3.UnEscape(action)
		if !ClipWait(1)
			return Notify.Show('there was an error copying the text to the clipboard', 'Error', 'Red', 'White')
		Send '^v'
		Sleep 250
		A_Clipboard := oldClip
	}
}

#HotIf Main.gui['menu'].Focused
Delete::Main.Delete()
#HotIf