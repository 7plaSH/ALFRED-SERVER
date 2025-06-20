import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN');
const TELEGRAM_CHAT_ID = Deno.env.get('TELEGRAM_CHAT_ID');
Deno.serve(async (_req)=>{
  try {
   
    const response = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
      method: 'GET',
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    });
    if (!response.ok) throw new Error('Failed to fetch users');
    const users = await response.json();
   
    const emailContent = "<h2>Появился новый маркер</h2>";
    const telegramText = 'Появился новый маркер на карте! Проверь информацию в приложении.';
    for (const user of users){
      if (!user.email) continue;
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RESEND_API_KEY}`
        },
        body: JSON.stringify({
          from: 'Map Project <onboarding@resend.dev>',
          to: user.email,
          subject: 'Новая метка на карте',
          html: emailContent
        })
      });
    }
    
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: telegramText
      })
    });
    return new Response(JSON.stringify({
      success: true
    }), {
      headers: {
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({
      error: error?.message || String(error)
    }), {
      headers: {
        'Content-Type': 'application/json'
      },
      status: 400
    });
  }
});
