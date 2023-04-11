package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"golang.org/x/exp/slog"
)

type RegistrationRequest struct {
	Name                string   `json:"name"`
	SupportedOperations []string `json:"supportedOperations"`
}

type RegistrationResponse struct {
	Name   string `json:"name"`
	ID     string `json:"id"`
	Parent string `json:"parent"`
}

type ErrorResponse struct {
	Message string `json:"message"`
	Details string `json:"details"`
}

func writeJSONResponse(w http.ResponseWriter, statusCode int, response any) {
	body, err := json.Marshal(response)
	if err != nil {
		slog.Error("Could not marshal response", err)
	}
	w.WriteHeader(statusCode)
	if _, err := w.Write(body); err != nil {
		log.Printf("Could not write to body. %s", err)
	}
}

func register(id string, baseDir string, sep string) func(w http.ResponseWriter, req *http.Request) {
	return func(w http.ResponseWriter, req *http.Request) {
		decoder := json.NewDecoder(req.Body)
		request := &RegistrationRequest{}
		if err := decoder.Decode(&request); err != nil {
			writeJSONResponse(w, http.StatusUnsupportedMediaType, &ErrorResponse{
				Message: "Could not parse registration request",
				Details: err.Error(),
			})
			return
		}

		deviceID := id
		if deviceID == "" {
			value, err := GetDeviceID()
			if err != nil {
				writeJSONResponse(w, http.StatusBadRequest, ErrorResponse{
					Message: "Could not get device id",
					Details: err.Error(),
				})
				return
			}
			deviceID = value
		}

		childID := strings.Join([]string{deviceID, request.Name}, sep)
		if err := RegisterDevice(childID, baseDir, request.SupportedOperations); err != nil {
			writeJSONResponse(w, http.StatusNotFound, ErrorResponse{
				Message: "Could not register device",
				Details: err.Error(),
			})
			return
		}

		writeJSONResponse(w, http.StatusOK, RegistrationResponse{
			Name:   request.Name,
			ID:     childID,
			Parent: deviceID,
		})
	}
}

func touchFile(name string) error {
	_, err := os.Stat(name)
	if os.IsExist(err) {
		// Do nothing
		return nil
	}

	if os.IsNotExist(err) {
		file, fileErr := os.Create(name)
		if fileErr != nil {
			return fileErr
		}
		defer file.Close()
		return nil
	}

	return err
}

func RegisterDevice(id string, baseDir string, supportedOperations []string) error {
	operationsDir := filepath.Join(baseDir, "operations", "c8y")
	if _, err := os.Stat(operationsDir); os.IsNotExist(err) {
		slog.Error("operations directory does not exist.", "path", baseDir)
		return err
	}

	childDIR := filepath.Join(operationsDir, id)
	if err := os.MkdirAll(childDIR, os.ModePerm); err != nil {
		slog.Error("Could not create operations directory for child", slog.String("error", err.Error()), slog.String("path", childDIR))
		return err
	}

	for _, opType := range supportedOperations {
		if err := touchFile(path.Join(childDIR, opType)); err != nil {
			return err
		}
	}

	return nil
}

// Get device id via the tedge cli
func GetDeviceID() (string, error) {
	cmd, err := exec.Command("tedge", "config", "get", "device.id").Output()
	if err != nil {
		slog.Error("Could not get device.id from tedge.", "error", err)
	}
	return string(cmd), err
}

func main() {
	var port int
	var deviceID string
	var configDir string
	var nameSeparator string
	flag.IntVar(&port, "port", 9000, "Port")
	flag.StringVar(&deviceID, "device-id", "", "Use static device id instead of using the tedge cli")
	flag.StringVar(&configDir, "config-dir", "/etc/tedge", "thin-edge.io base configuration directory")
	flag.StringVar(&nameSeparator, "separator", "_", "Device name separator")

	// Support setting flags via environment variables
	flag.VisitAll(func(f *flag.Flag) {
		envName := strings.ReplaceAll(strings.ToUpper(f.Name), "-", "_")
		if value := os.Getenv(envName); value != "" {
			f.Value.Set(value)
		}
	})
	flag.Parse()

	listenOn := fmt.Sprintf(":%d", port)
	slog.Info("Starting registration service.", "listen", listenOn, "deviceID", deviceID)
	http.HandleFunc("/register", register(deviceID, configDir, nameSeparator))
	http.ListenAndServe(listenOn, nil)
}
