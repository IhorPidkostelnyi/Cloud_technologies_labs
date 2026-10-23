from pydantic import BaseModel, ConfigDict, Field


class AuthorInput(BaseModel):
    name: str = Field(min_length=1, max_length=200, pattern=r"\S")


class AuthorOutput(AuthorInput):
    model_config = ConfigDict(from_attributes=True)
    id: int


class BookInput(BaseModel):
    title: str = Field(min_length=1, max_length=300, pattern=r"\S")
    year: int | None = Field(default=None, ge=1, le=2100)
    author_id: int = Field(gt=0)


class BookOutput(BookInput):
    model_config = ConfigDict(from_attributes=True)
    id: int
