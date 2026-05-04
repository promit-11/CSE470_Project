import fetch from 'node-fetch';
import mongoose from 'mongoose';

const API = 'http://127.0.0.1:8080/api/v1';

async function test() {
  // Connect to DB
  await mongoose.connect(process.env.MONGODB_URL || 'mongodb://localhost:27017/cse470_test');

  try {
    // Register and approve a teacher
    const regResp = await fetch(`${API}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Debug Teacher',
        email: 'debug_teacher@test.local',
        password: 'Teacher@12345',
        role: 'teacher',
      }),
    });

    if (regResp.status !== 201) {
      const err = await regResp.text();
      console.log('Register failed:', regResp.status, err);
      throw new Error('Registration failed');
    }

    const regData = await regResp.json();
    const teacherId = regData.data.user.id;
    console.log('✓ Teacher registered:', teacherId);

    // Login as admin
    const adminLoginResp = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'admin@g.com',
        password: 'Admin@12345',
      }),
    });

    if (adminLoginResp.status !== 200) {
      const err = await adminLoginResp.text();
      console.log('Admin login failed:', adminLoginResp.status, err);
      throw new Error('Admin login failed');
    }

    const adminData = await adminLoginResp.json();
    const adminToken = adminData.data.accessToken;
    console.log('✓ Admin logged in');

    // Approve teacher
    const approveResp = await fetch(`${API}/admin/teachers/${teacherId}/approve`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminToken}`,
      },
      body: JSON.stringify({}),
    });

    if (approveResp.status !== 200) {
      const err = await approveResp.text();
      console.log('Approve failed:', approveResp.status, err);
      throw new Error('Approval failed');
    }

    console.log('✓ Teacher approved');

    // Login as teacher
    const teacherLoginResp = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'debug_teacher@test.local',
        password: 'Teacher@12345',
      }),
    });

    if (teacherLoginResp.status !== 200) {
      const err = await teacherLoginResp.text();
      console.log('Teacher login failed:', teacherLoginResp.status, err);
      throw new Error('Teacher login failed');
    }

    const teacherData = await teacherLoginResp.json();
    const teacherToken = teacherData.data.accessToken;
    console.log('✓ Teacher logged in');

    // Request payout
    const payoutResp = await fetch(`${API}/teachers/payouts/request`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${teacherToken}`,
      },
      body: JSON.stringify({
        requestedRewardCredits: 5,
        note: 'test',
      }),
    });

    console.log('Payout response status:', payoutResp.status);
    const payoutBody = await payoutResp.text();
    console.log('Payout response body:', payoutBody);

    if (payoutResp.status !== 201) {
      console.log('✗ Payout request failed');
      try {
        const parsed = JSON.parse(payoutBody);
        console.log('Error message:', parsed.message);
      } catch (e) {
        console.log('Could not parse response as JSON');
      }
    } else {
      console.log('✓ Payout request succeeded');
    }
  } catch (e) {
    console.error('Test error:', e.message);
  } finally {
    await mongoose.disconnect();
  }
}

test();
