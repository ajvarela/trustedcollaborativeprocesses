import http from 'k6/http';
import { check, group, sleep, fail } from 'k6';

export default function() {
    const url = 'http://localhost:3001/test?nusers=1';
    const payload = JSON.stringify({});

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
        timeout: '1200s'
    };

    const res = http.post(url, payload, params);
    check(res, {
        'is status 200': (r) => r.status === 200,
    });
}