// zsirdns 仪表盘逻辑

document.addEventListener('DOMContentLoaded', () => {

    // 1. 初始化仪表盘组件
    initDashboard();

    // 2. 设置实时 DNS 日志的 WebSocket
    setupWebSocket();

    // 3. 刷新按钮交互
    document.getElementById('btn-refresh').addEventListener('click', (e) => {
        const btn = e.target;
        btn.textContent = '刷新中...';
        btn.style.opacity = '0.7';
        setTimeout(() => {
            updateMetrics();
            btn.textContent = '刷新数据';
            btn.style.opacity = '1';
        }, 600);
    });

    // 4. 导航点击处理程序
    const navItems = document.querySelectorAll('.nav-item');
    const viewSections = document.querySelectorAll('.view-section');

    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            viewSections.forEach(section => section.classList.remove('active'));

            const targetViewId = 'view-' + item.getAttribute('data-view');
            const targetElement = document.getElementById(targetViewId);
            if (targetElement) {
                targetElement.classList.add('active');
            }

            if (targetViewId === 'view-rules') {
                const iframe = document.getElementById('clash-iframe');
                if (!iframe.src || iframe.src === window.location.href) {
                    const host = window.location.hostname;
                    iframe.src = `http://${host}:9090/ui/`;
                }
            }
        });
    });
});

let myChart;

function initDashboard() {
    updateMetrics();
    initChart();

    setInterval(() => {
        updateMetrics();
        updateChartData();
    }, 2000);
}

function setupWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;
    const socket = new WebSocket(wsUrl);

    socket.onmessage = (event) => {
        const data = JSON.parse(event.data);
        addLogToTable(data);
    };

    socket.onclose = () => {
        console.log('WebSocket 连接已关闭。5 秒后重试...');
        setTimeout(setupWebSocket, 5000);
    };
}

function addLogToTable(log) {
    const tbody = document.getElementById('logs-tbody');
    const tr = document.createElement('tr');

    // 根据简单的规则或传入的数据确定标签
    const isCn = log.domain.endsWith('.cn') || log.result.includes('China');
    const badgeClass = isCn ? 'tag-cn' : 'tag-proxy';
    const tagText = isCn ? '国内' : '代理';

    tr.innerHTML = `
        <td class="domain-text">${log.domain}</td>
        <td><span class="tag-badge ${badgeClass}">${tagText}</span></td>
        <td style="color: #94a0b8">${log.type}</td>
        <td style="font-family: monospace; color: #10b981">${log.time}</td>
        <td style="color: #94a0b8">${log.result === 'Resolved' ? '已解析' : log.result}</td>
    `;

    // 插入到顶部
    if (tbody.firstChild) {
        tbody.insertBefore(tr, tbody.firstChild);
    } else {
        tbody.appendChild(tr);
    }

    // 仅保留最近 50 条日志
    if (tbody.children.length > 50) {
        tbody.removeChild(tbody.lastChild);
    }
}

function updateMetrics() {
    const qps = Math.floor(Math.random() * 500) + 1200;
    const cacheHit = (Math.random() * 5 + 90).toFixed(1);
    const connections = Math.floor(Math.random() * 50) + 120;
    const load = (Math.random() * 0.5 + 0.1).toFixed(2);

    animateValue('qps-value', qps, '');
    animateValue('cache-hit', cacheHit, '%');
    animateValue('proxy-conn', connections, '');
    animateValue('sys-load', load, '');
}

function initChart() {
    const ctx = document.getElementById('trafficChart').getContext('2d');

    const gradientBlue = ctx.createLinearGradient(0, 0, 0, 400);
    gradientBlue.addColorStop(0, 'rgba(59, 130, 246, 0.4)');
    gradientBlue.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

    const gradientPurple = ctx.createLinearGradient(0, 0, 0, 400);
    gradientPurple.addColorStop(0, 'rgba(139, 92, 246, 0.4)');
    gradientPurple.addColorStop(1, 'rgba(139, 92, 246, 0.0)');

    const labels = Array.from({ length: 15 }, (_, i) => `${15 - i}s 前`).reverse();
    const dataDomestic = Array.from({ length: 15 }, () => Math.floor(Math.random() * 500 + 500));
    const dataOverseas = Array.from({ length: 15 }, () => Math.floor(Math.random() * 200 + 100));

    myChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: '国内查询 (直连)',
                    data: dataDomestic,
                    borderColor: '#3b82f6',
                    backgroundColor: gradientBlue,
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true,
                    pointRadius: 0,
                    pointHoverRadius: 6
                },
                {
                    label: '海外查询 (代理)',
                    data: dataOverseas,
                    borderColor: '#8b5cf6',
                    backgroundColor: gradientPurple,
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true,
                    pointRadius: 0,
                    pointHoverRadius: 6
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    displayColors: true
                }
            },
            scales: {
                x: {
                    grid: { display: false, drawBorder: false },
                    ticks: { color: '#64748b' }
                },
                y: {
                    grid: { color: 'rgba(255, 255, 255, 0.05)', drawBorder: false },
                    ticks: { color: '#64748b' }
                }
            },
            interaction: { mode: 'nearest', axis: 'x', intersect: false }
        }
    });
}

function updateChartData() {
    if (!myChart) return;
    myChart.data.datasets[0].data.shift();
    myChart.data.datasets[1].data.shift();
    myChart.data.datasets[0].data.push(Math.floor(Math.random() * 500 + 500));
    myChart.data.datasets[1].data.push(Math.floor(Math.random() * 200 + 100));
    myChart.update('none');
}

function animateValue(id, value, suffix) {
    const el = document.getElementById(id);
    if (!el) return;
    el.innerText = value + suffix;
}
