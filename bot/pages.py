import discord


def chunk(items: list, size: int) -> list[list]:
    return [items[start : start + size] for start in range(0, len(items), size)] or [[]]


def columns(items: list[str], count: int = 3) -> list[str]:
    per_column = -(-len(items) // count) if items else 0
    return ["\n".join(items[start : start + per_column]) for start in range(0, len(items), per_column)] if items else []


def number(embeds: list[discord.Embed], suffix: str = "") -> list[discord.Embed]:
    for index, embed in enumerate(embeds, 1):
        text = f"Page {index}/{len(embeds)}" if len(embeds) > 1 else ""
        embed.set_footer(text=" · ".join(part for part in (text, suffix) if part) or None)
    return embeds


class Pages(discord.ui.View):
    def __init__(self, owner_id: int, embeds: list[discord.Embed]):
        super().__init__(timeout=300)
        self.owner_id = owner_id
        self.embeds = embeds
        self.index = 0
        self.message: discord.WebhookMessage | None = None
        self.refresh()

    def refresh(self):
        self.first.disabled = self.previous.disabled = self.index == 0
        self.next.disabled = self.last.disabled = self.index == len(self.embeds) - 1

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return interaction.user.id == self.owner_id

    async def show(self, interaction: discord.Interaction, index: int):
        self.index = max(0, min(index, len(self.embeds) - 1))
        self.refresh()
        await interaction.response.edit_message(embed=self.embeds[self.index], view=self)

    @discord.ui.button(label="«", style=discord.ButtonStyle.secondary)
    async def first(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.show(interaction, 0)

    @discord.ui.button(label="‹", style=discord.ButtonStyle.secondary)
    async def previous(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.show(interaction, self.index - 1)

    @discord.ui.button(label="›", style=discord.ButtonStyle.secondary)
    async def next(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.show(interaction, self.index + 1)

    @discord.ui.button(label="»", style=discord.ButtonStyle.secondary)
    async def last(self, interaction: discord.Interaction, button: discord.ui.Button):
        await self.show(interaction, len(self.embeds) - 1)

    async def on_timeout(self):
        if self.message:
            try:
                await self.message.edit(view=None)
            except discord.HTTPException:
                pass


async def send(interaction: discord.Interaction, embeds: list[discord.Embed]):
    if len(embeds) == 1:
        await interaction.followup.send(embed=embeds[0], ephemeral=True)
        return
    view = Pages(interaction.user.id, embeds)
    view.message = await interaction.followup.send(embed=embeds[0], view=view, ephemeral=True, wait=True)
