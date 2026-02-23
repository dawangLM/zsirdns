package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type DnsLog struct {
	Time   string `json:"time"`
	Domain string `json:"domain"`
	Type   string `json:"type"`
	Result string `json:"result"`
}

var clients = make(map[*websocket.Conn]bool)
var broadcast = make(chan DnsLog)

func main() {
	// 1. 模拟/读取 MosDNS 日志文件
	go tailLogFile("/Users/zw/Downloads/TitanDNS-online/zsirdns/mosdns.log")

	// 2. WebSocket 处理器
	http.HandleFunc("/ws", handleConnections)

	// 3. 静态文件服务 (UI)
	fs := http.FileServer(http.Dir("../ui"))
	http.Handle("/", fs)

	// 4. 广播协程
	go handleMessages()

	log.Println("Monitor server started at :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer ws.Close()

	clients[ws] = true

	for {
		_, _, err := ws.ReadMessage()
		if err != nil {
			delete(clients, ws)
			break
		}
	}
}

func handleMessages() {
	for {
		msg := <-broadcast
		for client := range clients {
			err := client.WriteJSON(msg)
			if err != nil {
				log.Printf("error: %v", err)
				client.Close()
				delete(clients, client)
			}
		}
	}
}

func tailLogFile(filePath string) {
	// 确保文件存在
	f, err := os.OpenFile(filePath, os.O_CREATE|os.O_RDONLY, 0644)
	if err != nil {
		log.Fatalf("failed to open log file: %v", err)
	}
	f.Close()

	// 这是一个非常简单的 tail 实现
	// 在生产环境中建议使用 github.com/hpcloud/tail
	for {
		file, err := os.Open(filePath)
		if err != nil {
			time.Sleep(1 * time.Second)
			continue
		}

		// 定位到末尾
		file.Seek(0, 2)
		reader := bufio.NewReader(file)

		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				time.Sleep(500 * time.Millisecond)
				continue
			}

			// 解析 MosDNS 日志行 (简化逻辑)
			// 假设日志格式包含 "query:" 和结果
			if strings.Contains(line, "query") {
				dnsLog := parseMosDnsLine(line)
				broadcast <- dnsLog
			}
		}
	}
}

func parseMosDnsLine(line string) DnsLog {
	// 示例日志: 2024-02-23T16:50:00Z INFO query: google.com type: A result: [1.2.3.4]
	parts := strings.Split(line, " ")
	domain := "unknown"
	qType := "A"
	for i, part := range parts {
		if part == "query:" && i+1 < len(parts) {
			domain = parts[i+1]
		}
		if part == "type:" && i+1 < len(parts) {
			qType = parts[i+1]
		}
	}

	return DnsLog{
		Time:   time.Now().Format("15:04:05"),
		Domain: domain,
		Type:   qType,
		Result: "Resolved",
	}
}
