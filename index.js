require('dotenv').config();

const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder } = require('discord.js');

const client = new Client({
  intents: [GatewayIntentBits.Guilds]
});

// Slash command
const commands = [
  new SlashCommandBuilder()
    .setName('ping')
    .setDescription('Shows votes remaining for vote party')
    .toJSON()
];

// Register command
const rest = new REST({ version: '10' }).setToken(process.env.TOKEN);

async function register() {
  await rest.put(
    Routes.applicationCommands(process.env.CLIENT_ID),
    { body: commands }
  );
}

client.once('ready', async () => {
  console.log(`Logged in as ${client.user.tag}`);
  await register();
});

// Handle command
client.on('interactionCreate', async interaction => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'ping') {
    await interaction.deferReply();

    try {
      const res = await fetch('https://api.earthmc.net/v4/');
      const data = await res.json();

      const remaining = data?.voteParty?.numRemaining;

      if (remaining === undefined) {
        return interaction.editReply('Could not find vote party data.');
      }

      await interaction.editReply(`🗳️ Votes remaining for vote party: **${remaining}**`);
    } catch (err) {
      await interaction.editReply('Failed to fetch EarthMC API.');
    }
  }
});

client.login(process.env.TOKEN);
