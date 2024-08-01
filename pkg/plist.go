package pkg

import (
	"fmt"
	"html/template"
	"os"
)

const plistTemplate = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.jschill.auto-focus</string>
	<key>ProgramArguments</key>
	<array>
		<string>{{.RepoPath}}/auto-focus/auto-focus</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/tmp/auto-focus.out</string>
	<key>StandardErrorPath</key>
	<string>/tmp/auto-focus.err</string>
</dict>
</plist>`

func GeneratePlist(repoPath string) error {
	tmpl, err := template.New("plist").Parse(plistTemplate)
	if err != nil {
		fmt.Println("Error parsing template:", err)
		return err
	}

	file, err := os.Create("com.jschill.auto-focus.plist")
	if err != nil {
		fmt.Println("Error creating plist file:", err)
		return err
	}
	defer file.Close()

	err = tmpl.Execute(file, struct{ RepoPath string }{RepoPath: repoPath})
	if err != nil {
		fmt.Println("Error executing template:", err)
		return err
	}

	fmt.Println("com.jschill.auto-focus.plist generated successfully")

	return nil
}
