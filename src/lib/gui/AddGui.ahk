class AddGui {
	static gui         := Gui('+ToolWindow +Owner' Main.gui.hwnd,'Add Item')
	static editing     := false
	static placeholder := 'res\ico\002-txt-1.ico'

	static __New()
	{
		basicWidth  := 500
		basicBtnLoc := basicWidth + AddGui.gui.MarginX * 2 - (75 * 2)
	
		AddGui.gui.b64Icon := ''
		AddGui.gui.AddGroupBox('x+' (basicWidth/2) - (75/2) ' ym w75 r3.5 Section','Icon')
		AddGui.gui.AddPicture('vIcon xp+6 yp+17 w64 h-1', AddGui.placeholder)
		AddGui.gui.AddButton('xs y+15 w75', 'Change Icon').OnEvent('Click', (*)=>AddGui.PickIcon())
		AddGui.gui.AddGroupBox('xm y+m w' basicWidth + AddGui.gui.MarginX*2 ' r1','Type')
		AddGui.gui.AddRadio('vType xp10 yp+15 Checked','Text').OnEvent('Click', (*)=> AddGui.CtrlStatusHandler())
		AddGui.gui.AddRadio('x+m','Submenu').OnEvent('Click', (*)=> AddGui.CtrlStatusHandler())
		AddGui.gui.AddGroupBox('xm w' basicWidth + AddGui.gui.MarginX*2 ' r7.5', 'Parent')
		AddGui.gui.AddListBox('vParents xp+10 yp+15 w' basicWidth ' r10')

		lblYMargin := AddGui.gui.MarginY+6
		lblXMargin := AddGui.gui.MarginX*2
		AddGui.gui.AddGroupBox('xm w' basicWidth + AddGui.gui.MarginX*2 ' r5', 'General Info')
		AddGui.gui.AddText('xp+10 yp+20', 'Label:')
		AddGui.gui.AddEdit('vLabel x+60 yp-3 w150 Section')
		AddGui.gui.AddText('vHKLabel x' lblXMargin ' y+' lblYMargin, 'Hotkey:')
		AddGui.gui.AddHotkey('vHotkey xs yp-3 w150')
		AddGui.gui.AddText('vHSLabel x' lblXMargin ' y+' lblYMargin, 'Text Expansion:')
		AddGui.gui.AddEdit('vHotstring xs yp-3 w150')

		AddGui.gui.AddGroupBox('xm w' basicWidth + AddGui.gui.MarginX*2 ' r7.5', 'Snippet')
		AddGui.gui.AddEdit('vSnippet xp+10 yp+15 w' basicWidth ' r10')
		AddGui.gui.AddButton('vAddBtn x' basicBtnLoc ' w75', 'Add')
		          .OnEvent('Click', (*)=>AddGui.Save())
		AddGui.gui.AddButton('x+m w75', 'Cancel')
		          .OnEvent('Click', (*)=>AddGui.gui.Hide())
		; AddGui.gui.Show()
		return
	}

	static Show(button)
	{
		AddGui.gui['Parents'].Delete()
		while id := Main.gui['smTree'].GetNext(id??0,'full')
			AddGui.gui['Parents'].Add(Main.BuildTVPath(id))

		selected := Main.BuildTVPath(Main.gui['smTree'].GetSelection())

		; no item selected, we are editing a submenu
		; remove itself from the path
		if !Main.gui['menu'].GetNext()
		&& button != Main.gui['Add']
			selected[1] := RegExReplace(selected[1], '\s>[^>]+?$')

		AddGui.gui['Parents'].Choose(selected[1])

		; saved      := AddGui.gui.Submit(false)
		; if saved.type = 2
		; 	AddGui.gui['Icon'].value := 'res\ico\arrow.ico'

		AddGui.gui.Show()
	}

	static Save()
	{
		static lvInfo  := Main.lvInfo
		static tvInfo  := Main.tvInfo
		static tvpInfo := Main.tvpInfo

		parentInfo := AddGui.GetParent()
		saved      := AddGui.gui.Submit(false)
		item       := [
			saved.type = 2 ? 'MENU' : 'TXT',
			AddGui.gui['Label'].Value,
			Main.HKToString(AddGui.gui['Hotkey'].Value),
			saved.type = 2 ? '----' : AddGui.gui['Hotstring'].Value,
			saved.type = 2 ? '--------------------------------------' : AddGui.gui['Snippet'].Value,
			AddGui.editing ? AddGui.editing.id : A_Now,
			parentName := parentInfo.id,
			AddGui.gui.b64Icon,
			''
		]

		if !AddGui.gui.b64Icon
		{
			switch saved.type
			{
				case 1:
					icoPath := 'res\ico\002-txt-1.ico'
				case 2:
					icoPath := 'res\ico\arrow.ico'
			}
			rawData := FileRead(icoPath, 'RAW')
			AddGui.gui.b64Icon := B64Encode(rawData, 'RAW')
		}

		b64Icon := item[8] := AddGui.gui.b64Icon

		lvInfo.Set(item[6], item)

		icon_index := IL_Add(Main.Icon.list, 'HBITMAP:' HandleFromBase64(b64Icon, false))
		Main.Icon.data.Set(item[6], icon_index ?? -1)

		if parentInfo.tvID = Main.gui['smTree'].GetSelection()
		{
			if AddGui.editing
			{
				item[9] := AddGui.editing.row

				if saved.type = 2
					Main.gui['menu'].Delete(AddGui.editing.row)
				else
					Main.gui['menu'].Modify(AddGui.editing.row, 'Icon' Main.Icon.data[item[6]], item*)
			}
			else
			{
				pos := Main.gui['menu'].Add('Icon' Main.Icon.data[item[6]], item*)
				item[9] := pos
				main.gui['menu'].Modify(pos, '', item*)
			}
		}
		else
		{
			pos := 0
			for itemId, row in lvInfo
				if row[7] = parentInfo.id
					pos++
			item[9] := pos

			if AddGui.editing && AddGui.editing.row
				Main.gui['menu'].Delete(AddGui.editing.row)
		}

		if saved.type = 2 ; Submenu
		{
			if AddGui.editing
			{
				; make sure the treeview parent structure is updated
				Main.gui['smTree'].Delete(tvInfo[AddGui.editing.id])
				tvID := Main.gui['smTree'].Add(
					AddGui.gui['Label'].Value,
					tvInfo[item[7]],
					'Expand Icon' Main.Icon.data[item[6]]
				)

				if AddGui.editing.row
					Main.gui['menu'].Delete(AddGui.editing.row)
				pos := 0
				for itemId, row in lvInfo
				{
					if row[7] = item[7]
						pos++
				}
				item[9] := pos
			}
			else
				tvID := Main.gui['smTree'].Add(
					AddGui.gui['Label'].Value,
					parentInfo.tvID,
					'Expand Icon' Main.Icon.data[item[6]],
				)

			tvInfo.Set(item[6], tvID)
			tvpInfo.Set(tvID, item[6])
		}

		Main.ResetTriggers()
		Main.ResetPos()
		Main.LoadMenu()
		Main.AutoFitColumns()

		AddGui.editing := false
		AddGui.gui.Hide()
	}

	static GetParent()
	{
		static tvpInfo := Main.tvpInfo
		static lbCtrl  := AddGui.gui['Parents']


		path       := StrSplit(lbCtrl.text, ' > ')
		targetName := path[path.Length]
		for item in path
		{
			OutputDebug item '`n'
			while tvID := Main.gui['smTree'].GetNext(tvID ?? 0, 'Full')
				if item = Main.gui['smTree'].GetText(tvID)
					id := tvID
		}

		return {tvID: id, id:tvpInfo[id]}
	}

	static CtrlStatusHandler()
	{

		values := AddGui.gui.Submit(false)

		switch values.Type
		{
		case 1:
			if AddGui.gui.b64Icon
				icoPath := Main.tmpIcon
			else
				icoPath := 'res\ico\002-txt-1.ico'
			for ctrl in AddGui.gui
			{
				switch ctrl.Name
				{
				case 'snippet',
				     'BrowseFile','BrowseFolder':
					ctrl.Enabled := false
				default:
					ctrl.Enabled := true
				}
			}
		case 2:
			if AddGui.gui.b64Icon
				icoPath := Main.tmpIcon
			else
				icoPath := 'res\ico\arrow.ico'
			for ctrl in AddGui.gui
			{
				switch ctrl.Name
				{
				case 'snippet','BrowseFile',
				     'BrowseFolder','HSLabel','Hotstring',
				     'Snippet':
					ctrl.Enabled := false
				default:
					ctrl.Enabled := true
				}
			}
		}

		rawData := FileRead(icoPath, 'RAW')
		AddGui.gui['Icon'].value := icoPath
		AddGui.gui.b64Icon := B64Encode(rawData, 'RAW')
	}

	static PickIcon()
	{
		static MAX_PATH := 260

		pszIconPath := Buffer(MAX_PATH)
		StrPut(A_ScriptDir '\' AddGui.placeholder, pszIconPath)

		if !DllCall('Shell32\PickIconDlg',
				'ptr' , AddGui.gui.Hwnd,
				'ptr' , pszIconPath,
				'uint', pszIconPath.size,
				'ptr*', &icon := 0)
			return


		if (icoPath := StrGet(pszIconPath)) ~= 'i)\.ico' = 0
			return Notify.Show('Selected image should be an icon file (*.ico)', 'Failed',
				           'Red', 'White')

		if InStr(FileExist(icoPath), 'D')
			return Notify.Show('You cant select a folder', 'Failed',
				           'Red', 'White')

		rawData := FileRead(icoPath, 'RAW')
		AddGui.gui['Icon'].value := icoPath
		AddGui.gui.b64Icon := B64Encode(rawData, 'RAW')
	}
}