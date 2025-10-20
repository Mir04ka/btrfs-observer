// Copyright 2015 Daniel Theophanes.
// Use of this source code is governed by a zlib-style
// license that can be found in the LICENSE file.

// simple does nothing except block while running the service.
package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"log/syslog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gen2brain/beeep"
	"github.com/kardianos/service" // background process
)

// System notifications

var WarnLevel = map[int]string{
	0: "assets/blue_info.png",
	1: "assets/yellow_warning.png",
	2: "assets/red_alert.png",
}

func notify(warnLevel int, title string, message string) {
	err := beeep.Notify(title, message, WarnLevel[warnLevel])
	if err != nil {
		log.Printf("Notify error: %v", err)
	}
}

// Config file

func readSettingsFile() (disks []string, timeout int) {
	home, err := os.UserHomeDir()
	if err != nil {
		log.Printf("Error getting home dir: %v", err)
		return nil, 30
	}

	dir := filepath.Join(home, ".local", "share", "btrfs_observer")
	if err := os.MkdirAll(dir, 0755); err != nil {
		log.Printf("Can't create config dir %s: %v\n", dir, err)
	}

	timeoutFile, err := os.OpenFile(home+"/.local/share/btrfs_observer/timeout.txt", os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		log.Fatalf("File opening error: %v", err)
	}
	defer timeoutFile.Close()

	buf := make([]byte, 100)
	n, err := timeoutFile.Read(buf)
	if err != nil && err != io.EOF {
		log.Fatalf("Read error: %v", err)
	}

	str := strings.TrimSpace(string(buf[:n]))
	timeout, err = strconv.Atoi(str)

	disksFile, err := os.OpenFile(home+"/.local/share/btrfs_observer/disks.txt", os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		log.Fatalf("File opening error: %v", err)
	}
	defer disksFile.Close()

	scanner := bufio.NewScanner(disksFile)
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			disks = append(disks, line)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatalf("Scanner error: %v", err)
	}

	return
}

// Background process

var logger service.Logger

type program struct{}

func (p *program) Start(s service.Service) error {
	notify(0, "Service started", "BTRFS Observer is working now")

	go p.run()
	return nil
}

func (p *program) run() {
	for {
		disks, timeout := readSettingsFile()

		for _, disk := range disks {
			cmd := exec.Command("sudo", "btrfs", "device", "stats", disk)
			output, err := cmd.CombinedOutput()
			if err != nil {
				log.Fatalf("Exec error: %v\nВывод: %s", err, output)
			}

			lines := strings.Split(string(output), "\n")

			numbers := []int{}
			errsNum := 0
			for _, line := range lines {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					var num int
					_, err = fmt.Sscanf(fields[1], "%d", &num)
					if err != nil {
						log.Printf("Error parsing numbers: %v", err)
					}
					numbers = append(numbers, num)
					errsNum += num
				}
			}

			if errsNum > 0 {
				notify(2, disk+" errors found", fmt.Sprintf("write_io_errs    %d\nread_io_errs     %d\nflush_io_errs    %d\ncorruption_errs  %d\ngeneration_errs  %d", numbers[0], numbers[1], numbers[2], numbers[3], numbers[4]))
			}
		}

		time.Sleep(time.Duration(timeout) * time.Second)
	}
}

func (p *program) Stop(s service.Service) error {
	notify(1, "Service stopped", "BTRFS Observer is NOT working now")

	return nil
}

// Main

func main() {
	// Notifications init
	beeep.AppName = "BTRFS Observer"

	// Background service init
	svcConfig := &service.Config{
		Name:        "BTRFSObserver",
		DisplayName: "BTRFS Observer",
		Description: "Observes BTRFS corruption errors",
	}

	// Logger init
	sysLog, err := syslog.New(syslog.LOG_INFO|syslog.LOG_LOCAL0, "myapp")
	if err != nil {
		log.Fatalf("Failed to connect to syslog: %v", err)
	}
	defer sysLog.Close()

	log.SetOutput(sysLog)

	// Background service define
	prg := &program{}
	s, err := service.New(prg, svcConfig)
	if err != nil {
		log.Fatal(err)
	}
	logger, err = s.Logger(nil)
	if err != nil {
		log.Fatal(err)
	}
	err = s.Run()
	if err != nil {
		logger.Error(err)
	}
}
